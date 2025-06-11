// lib/features/chatbot/screens/chatbot.dart

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

import '../../../l10n/app_localizations.dart';

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

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    if (_apiKey.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Ensure widget is still mounted
          _showSnackbar(
            localizations.chatApiKeyNotConfigured,
            duration: const Duration(seconds: 10),
          );
        }
      });
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
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
      if (mounted) {
        setState(() => _isInitialized = false);
      }
      return;
    }
    try {
      // UPDATED SYSTEM PROMPT with more app context
      const systemPrompt =
          "You are Harki, a helpful and empathetic AI assistant for the Harkai citizen security app. "
          "Your primary goal is to provide clear, concise, and actionable advice related to personal safety and community security. "
          "Maintain a supportive and calm tone. If a user seems distressed, offer to help them find appropriate resources if possible. "
          "Keep responses focused on the context of citizen security. Do not engage in off-topic conversations. "
          "Answer in the language the user is using on the message if it spanish give priority to this language at all times. "
          "\n\n" // Added newline for readability
          "Familiarize yourself with the Harkai app's key features so you can assist users effectively. These include: "
          "- A real-time, shared map where users can report incidents they witness (like fires, car crashes, thefts, or lost/found pets). These reports become visible as markers/alerts to other users in the area. "
          "- Four main alert buttons on the home screen for quick reporting: "
          "  - 'Fire Alert': Allows users to mark a fire location on the map and provides quick access to call the local fire station. "
          "  - 'Car Crash Alert': Allows users to mark a crash location and helps call local emergency services or relevant authorities (like Serenazgo). "
          "  - 'Theft Alert': For reporting robberies or burglaries, marking the location, and facilitating calls to the police. "
          "  - 'Pet Alert': For reporting lost or found pets, marking their location, and helping connect with animal rescue centers or shelters. Pet alerts on the incident feed screen have extended visibility (typically for the day of the report). "
          "- A new 'Add Place' feature that allows users to add businesses, stores, parks, and other points of interest to the map. This is different from reporting an incident. "
          "  - Adding a place requires a small payment to be processed in the app. "
          "  - It is mandatory to add a photo of the place, which can be taken with the camera or uploaded from the gallery. "
          "- Tapping an alert button on the home screen usually initiates a report. This process may involve the user providing an audio description, a text description, and an optional image of the incident. This media can be analyzed by an AI (like you, but in a different process) to help confirm the incident type and details before submission. "
          "- Long-pressing an alert button on the home screen (Fire, Crash, Theft, Pet, or the general 'Emergency' button in the bottom bar) opens an 'Incident Feed' screen. This screen lists recent, nearby incidents of that specific type, showing the description, an image/icon, and the distance from the user's current location. "
          "- Tapping an incident tile in the 'Incident Feed' screen opens a map modal. This modal displays the specific incident's location, the user's current location (blue dot), and, if possible, a path (route) between the user and the incident. "
          "- The app sends notifications to users when they are near a registered place, with messages like 'Discover a New Place', 'You're Almost There!', and 'Welcome!'. "
          "- The app also has a user profile section for account management (e.g., viewing email, option to change password). "
          "- You, Harki (the chatbot), are available to answer questions about these features, provide safety tips, or general assistance related to citizen security within the app's context. "
          "When users ask about how to use a feature, what a feature does, or what happens after an action (e.g., 'What happens if I long-press the fire button?'), use this knowledge to guide them clearly.";
      _model = GenerativeModel(
        model: 'gemini-1.5-flash', // Consider 'gemini-pro' if you need more complex reasoning and have it available
        apiKey: _apiKey,
        systemInstruction: Content.system(systemPrompt), // Use Content.system for system instructions
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 800, // Increased slightly for potentially more detailed explanations
        ),
      );

      _session = _model.startChat(history: []);
      if (mounted) {
        setState(() => _isInitialized = true);
        _showSnackbar(localizations.chatHarkiAiInitializedSuccess, success: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('${localizations.chatHarkiAiInitFailedPrefix}${e.toString()}');
        setState(() => _isInitialized = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty ||
        _isLoadingResponse ||
        !_isInitialized ||
        _session == null) {
      if (!mounted) return;
      if (!_isInitialized) {
        _showSnackbar(localizations.chatHarkiAiNotInitializedOnSend);
      } else if (_session == null) {
        _showSnackbar(localizations.chatSessionNotStartedOnSend);
      }
      return;
    }
    final messageText = _messageController.text;
    _messageController.clear();

    if (mounted) {
      setState(() {
        _isLoadingResponse = true;
        _messages.add(ChatMessage(message: messageText, isHarki: false));
      });
    }

    try {
      final response = await _session!.sendMessage(Content.text(messageText));
      final harkiResponseText = response.text;

      if (!mounted) return; // Check again before updating UI

      if (harkiResponseText == null || harkiResponseText.isEmpty) {
        _showSnackbar(localizations.chatHarkiAiEmptyResponse);
        _messages.add(ChatMessage(
            message: localizations.chatHarkiAiEmptyResponseFallbackMessage,
            isHarki: true));
      } else {
        _messages.add(ChatMessage(message: harkiResponseText, isHarki: true));
      }
    } catch (e) {
      if (!mounted) return; // Check again
      _showSnackbar('${localizations.chatSendMessageFailedPrefix}${e.toString()}');
      _messages.add(ChatMessage(
          message: localizations.chatSendMessageErrorFallbackMessage,
          isHarki: true));
    } finally {
      if (mounted) {
        setState(() => _isLoadingResponse = false);
      }
    }
  }

  void _showSnackbar(String message,
      {bool success = false, Duration duration = const Duration(seconds: 4)}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green[600] : Colors.red[600],
          duration: duration,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
        title: Text(localizations.chatScreenTitle,
            style: const TextStyle(color: Color(0xFF57D463))),
        iconTheme: const IconThemeData(color: Color(0xFF57D463)), // Makes back arrow green
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
              if (!_isInitialized && !_isLoadingResponse)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 2),
                      const SizedBox(width: 16),
                      Text(localizations.chatInitializingHarkiAiText,
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
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        return Padding( // Added padding around each message row
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                message.isHarki ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (message.isHarki) _buildBotAvatar(),
              _buildMessageBubble(message),
              if (!message.isHarki) _buildUserAvatar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserAvatar() {
    return Padding(
      padding: const EdgeInsets.only(
          left: 8.0, right: 0.0, top: 10.0), // Adjusted padding
      child: CircleAvatar(
        radius: 16, // Slightly smaller avatar
        backgroundImage:
            user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
        backgroundColor: Colors.blueGrey[100],
        child: user?.photoURL == null
            ? Icon(Icons.person, color: Colors.blueGrey[700], size: 20)
            : null,
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Padding(
      padding: const EdgeInsets.only(
          left: 0.0, right: 8.0, top: 10.0), // Adjusted padding
      child: CircleAvatar(
        radius: 18, // Outer circle for slight border effect
        backgroundColor: const Color(0xFF57D463).withAlpha((0.3 * 255).toInt()),
        child: const CircleAvatar(
          radius: 16, // Slightly smaller avatar
          backgroundImage: AssetImage('assets/images/bot.png'),
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    bool isHarki = message.isHarki;
    return Flexible(
      child: Container(
        margin: EdgeInsets.only(
          left: isHarki ? 0 : MediaQuery.of(context).size.width * 0.1, // Push user messages a bit
          right: isHarki ? MediaQuery.of(context).size.width * 0.1 : 0, // Push Harki messages a bit
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isHarki
              ? const Color(0xFFE8F5E9) // Lighter green for Harki
              : const Color(0xFFE3F2FD), // Lighter blue for User
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft:
                isHarki ? const Radius.circular(4) : const Radius.circular(18),
            bottomRight:
                isHarki ? const Radius.circular(18) : const Radius.circular(4),
          ),
           boxShadow: [ // Subtle shadow for bubbles
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isHarki ? CrossAxisAlignment.start : CrossAxisAlignment.start, // Both start for better readability
          children: [
            Text(
              isHarki ? localizations.chatSenderNameHarki : (user?.displayName ?? localizations.chatSenderNameUserFallback),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isHarki
                    ? Colors.green[800]
                    : Colors.blue[800],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 5),
            SelectableText( // Made text selectable
              message.message,
              style: TextStyle(
                color: Colors.black87, 
                fontSize: 15, 
                height: 1.4, // Improved line height
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
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
          Text(localizations.chatHarkiIsTypingText, style: const TextStyle(color: Colors.grey))
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 12.0), // Adjusted padding
      child: Row(
        children: [
          Expanded(
            child: Container( // Wrapped TextField in a Container for styling
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                enabled: _isInitialized && !_isLoadingResponse,
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                decoration: InputDecoration(
                  hintText: _isInitialized
                      ? localizations.chatMessageHintReady
                      : localizations.chatMessageHintInitializing,
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none, // Removed border from TextField itself
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // Adjusted padding
                ),
                onSubmitted: (_isLoadingResponse || !_isInitialized)
                    ? null
                    : (_) => _sendMessage(),
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3, // Allow multi-line input
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material( // Added Material for IconButton splash and shadow
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(25),
            elevation: 2.0,
            child: InkWell(
              borderRadius: BorderRadius.circular(25),
              onTap: (_isLoadingResponse || !_isInitialized) ? null : _sendMessage,
              child: Padding(
                padding: const EdgeInsets.all(12.0), // Consistent padding
                child: _isLoadingResponse
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white,
                        size: 24), // Adjusted size
              ),
            ),
          ),
        ],
      ),
    );
  }
}