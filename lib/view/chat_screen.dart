import 'dart:developer';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:chat_app/controller/chat_controller.dart';
import 'package:chat_app/controller/user_controller.dart';
import 'package:chat_app/view/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─── GEMINI CONFIG ────────────────────────────────────────────────────────────
const String _geminiApiKey = "AIzaSyAjH1zEBFjSgR87URs-anGIZdGyu7ByUCI";
// ──────────────────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatController _chatController = ChatController();
  final UserController _userController = UserController();
  final ScrollController _scrollController = ScrollController();

  bool _isGeminiTyping = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _userController.getUserData();
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // ✅ Safe name — never allow API key or long strings as name
    final String safeName = _getSafeName(_userController.name);

    final Map<String, dynamic> userMsg = {
      "profileImage": _userController.profileImage ?? "",
      "userId": _userController.userId ?? "unknown",
      "name": safeName,
      "message": text,
      "time": Timestamp.now(),
      "isBot": false,
    };

    await _chatController.sendMessage(messageBody: userMsg);
    _messageController.clear();
    _scrollToBottom();

    setState(() => _isGeminiTyping = true);

    final geminiReply = await _callGeminiAPI(text);

    final Map<String, dynamic> botMsg = {
      "profileImage": "",
      "userId": "gemini_bot",
      "name": "Gemini AI",
      "message": geminiReply,
      "time": Timestamp.now(),
      "isBot": true,
    };

    await _chatController.sendMessage(messageBody: botMsg);
    setState(() => _isGeminiTyping = false);
    _scrollToBottom();
  }

  /// ✅ Sanitize name — if it's suspicious (too long, looks like a key), use fallback
  String _getSafeName(String? name) {
    if (name == null || name.trim().isEmpty) return "User";
    if (name.trim().length > 30) return "User"; // API keys are 39 chars
    if (name.startsWith("AIza")) return "User"; // Gemini API key prefix
    return name.trim();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GEMINI API — with 429 retry + model fallback
  // ──────────────────────────────────────────────────────────────────────────
  Future<String> _callGeminiAPI(String prompt) async {
    final List<String> models = [
      "gemini-2.0-flash",
      "gemini-1.5-flash",
      "gemini-pro",
    ];

    for (final model in models) {
      try {
        final url =
            "https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$_geminiApiKey";

        final response = await http.post(
          Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {"text": prompt},
                ],
              },
            ],
            "generationConfig": {"temperature": 0.9, "maxOutputTokens": 1024},
          }),
        );

        log("Gemini [$model] status: ${response.statusCode}");

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final reply =
              data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"];
          if (reply != null && reply.toString().isNotEmpty) {
            return reply.toString().trim();
          }
        } else if (response.statusCode == 429) {
          // ✅ Rate limited — parse retry delay and show friendly message
          log("Gemini 429 on $model — quota exceeded");
          final errData = jsonDecode(response.body);
          final message = errData["error"]?["message"] ?? "";

          // Extract retry delay if available
          final retryMatch = RegExp(r'retry in (\d+)').firstMatch(message);
          final retrySeconds = retryMatch?.group(1) ?? "60";

          // Try next model before giving up
          continue;
        } else if (response.statusCode == 404) {
          log("Model $model not found, trying next...");
          continue;
        } else {
          log("Gemini error: ${response.body}");
          final errData = jsonDecode(response.body);
          return "⚠️ Error: ${errData["error"]?["message"] ?? "Unknown error"}";
        }
      } catch (e) {
        log("Gemini exception [$model]: $e");
        continue;
      }
    }

    // All models exhausted
    return "⚠️ Rate limit reached on all models.\n\n"
        "Your free tier quota is exhausted for today. Options:\n"
        "• Wait until tomorrow (free tier resets daily)\n"
        "• Create a new API key at aistudio.google.com\n"
        "• Enable billing on your Google Cloud project";
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(),
      body: Column(
        children: [Expanded(child: _buildChatArea()), _buildInputBar()],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 70,
      backgroundColor: Colors.white,
      elevation: 1,
      title: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF4285F4), Color(0xFF9B59B6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text("✨", style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Gemini Chat",
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                _isGeminiTyping ? "Gemini is typing..." : "AI Powered",
                style: TextStyle(
                  color: _isGeminiTyping ? Colors.green : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          icon: const Icon(Icons.logout, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildChatArea() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEFF3FF), Color(0xFFF8F0FF)],
              ),
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _chatController.getMessages(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("✨", style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      "Say something to Gemini AI!",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            final messages = snapshot.data!.docs;

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: messages.length + (_isGeminiTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isGeminiTyping && index == messages.length) {
                  return _typingIndicatorBubble();
                }

                final data = messages[index];
                final bool isBot = (data["userId"] == "gemini_bot");

                return messageCard(
                  userId: data["userId"] ?? "",
                  profileImage: data["profileImage"] ?? "",
                  // ✅ Always sanitize name from Firestore too
                  name: _getSafeName(data["name"]),
                  message: data["message"] ?? "",
                  time: data["time"],
                  docId: messages[index].id,
                  isBot: isBot,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: "Ask Gemini anything...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isGeminiTyping ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors:
                      _isGeminiTyping
                          ? [Colors.grey.shade400, Colors.grey.shade500]
                          : [const Color(0xFF4285F4), const Color(0xFF9B59B6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingIndicatorBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _geminiAvatar(small: true),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => _dot(i)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.grey.shade400,
              const Color(0xFF4285F4),
              value,
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget messageCard({
    required String userId,
    required String profileImage,
    required String name,
    required String message,
    required Timestamp time,
    required String docId,
    required bool isBot,
  }) {
    final bool isMe = _userController.userId == userId && !isBot;

    // ✅ Override name for bot messages always
    final String displayName = isBot ? "Gemini AI" : name;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            isBot ? _geminiAvatar(small: true) : _userAvatar(profileImage),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient:
                    isBot
                        ? const LinearGradient(
                          colors: [Color(0xFFEBF0FF), Color(0xFFF3EBFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                        : null,
                color:
                    isBot
                        ? null
                        : isMe
                        ? const Color(0xFFDCF8C6)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft:
                      isMe
                          ? const Radius.circular(18)
                          : const Radius.circular(0),
                  bottomRight:
                      isMe
                          ? const Radius.circular(0)
                          : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
                border:
                    isBot
                        ? Border.all(color: const Color(0xFFD0BBFF), width: 1)
                        : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ FIXED: Name row uses Flexible to prevent overflow
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isBot)
                            const Text("✨ ", style: TextStyle(fontSize: 12)),
                          // ✅ Flexible prevents overflow on long names
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    isBot
                                        ? const Color(0xFF7B4FD4)
                                        : Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      TimeOfDay.fromDateTime(time.toDate()).format(context),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _geminiAvatar({bool small = false}) {
    final size = small ? 30.0 : 40.0;
    return Container(
      height: size,
      width: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF4285F4), Color(0xFF9B59B6)],
        ),
      ),
      child: Center(
        child: Text("✨", style: TextStyle(fontSize: small ? 14 : 18)),
      ),
    );
  }

  Widget _userAvatar(String profileImage) {
    return CircleAvatar(
      radius: 16,
      backgroundImage:
          profileImage.isEmpty
              ? const NetworkImage(
                "https://play-lh.googleusercontent.com/Il1s7VYRV23p_J7m1rS8y96ldviGz0aCF31d_fLN1Yjaa8MrZGaNhqGe7uD7mHvXR2vu",
              )
              : NetworkImage(profileImage),
    );
  }
}
