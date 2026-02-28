import 'dart:async';

import 'package:chat_app/Cubit/search_cubit.dart';
import 'package:chat_app/Cubit/search_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class _ChatMessage {
  final String message;
  final String role;
  final DateTime timestamp;

  const _ChatMessage({
    required this.message,
    required this.role,
    required this.timestamp,
  });

  bool get isUser => role == 'user';

  factory _ChatMessage.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _ChatMessage(
      message: d['message'] ?? '',
      role: d['role'] ?? 'user',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'message': message,
        'role': role,
        'timestamp': FieldValue.serverTimestamp(),
      };
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final CollectionReference _chatsRef =
      FirebaseFirestore.instance.collection('chats');

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isClearing = false;
  String? _pendingQuery;
  StreamSubscription<QuerySnapshot>? _sub;

  // ── Colors ─────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF5F7FA);
  static const _appBarBg = Colors.white;
  static const _userBubble = Color(0xFF4F7FFF);
  static const _botBubble = Colors.white;
  static const _inputBarBg = Colors.white;
  static const _inputFieldBg = Color(0xFFF0F2F7);
  static const _sendActive = Color(0xFF4F7FFF);
  static const _sendInactive = Color(0xFFBEC5D1);
  static const _textOnUser = Colors.white;
  static const _textOnBot = Color(0xFF1A1D2E);
  static const _subtleText = Color(0xFF9CA3AF);
  static const _divider = Color(0xFFE8ECF4);

  @override
  void initState() {
    super.initState();
    _listenToFirestore();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  void _listenToFirestore() {
    _sub = _chatsRef
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(snap.docs.map(_ChatMessage.fromDoc));
      });
      _scrollToBottom();
    });
  }

  Future<void> _save(_ChatMessage msg) => _chatsRef.add(msg.toMap());

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _pendingQuery = text;
    _inputController.clear();
    setState(() => _isLoading = true);

    context.read<SearchCubit>().getSearchResponse(query: text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  // ── Clear Chat ─────────────────────────────────────────────────────────────

  Future<void> _clearAllMessages() async {
    setState(() => _isClearing = true);
    try {
      final snap = await _chatsRef.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded,
                color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text(
              'Clear Chat',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete all messages from Firebase. This cannot be undone.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _clearAllMessages();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat cleared successfully'),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<SearchCubit, SearchState>(
      listener: (ctx, state) async {
        if (state is SearchLoadedState) {
          if (_pendingQuery != null) {
            await _save(_ChatMessage(
              message: _pendingQuery!,
              role: 'user',
              timestamp: DateTime.now(),
            ));
            _pendingQuery = null;
          }
          await _save(_ChatMessage(
            message: state.res,
            role: 'bot',
            timestamp: DateTime.now(),
          ));
          if (mounted) setState(() => _isLoading = false);
          _scrollToBottom();
        } else if (state is SearchErrorState) {
          if (mounted) setState(() => _isLoading = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.errorMsg)));
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        floatingActionButton: _messages.isEmpty
            ? null
            : _isClearing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.redAccent,
                    ),
                  )
                : const Icon(
                    Icons.delete_sweep_rounded,
                    color: Colors.redAccent,
                    size: 26,
                  ),
        floatingActionButtonLocation: const CenterRightFabLocation(),
        body: Column(
          children: [
            Expanded(child: _buildList()),
            if (_isLoading) _buildTypingBubble(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _appBarBg,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF4F7FFF), Color(0xFF9B6FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F7FFF).withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '✦',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Assistant',
                style: TextStyle(
                  color: Color(0xFF1A1D2E),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _isLoading
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _isLoading ? 'Thinking…' : 'Online',
                      key: ValueKey(_isLoading),
                      style: const TextStyle(
                        color: _subtleText,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _divider, height: 1),
      ),
    );
  }

  Widget _buildList() {
    if (_messages.isEmpty && !_isLoading) return _buildEmptyState();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) => _AnimatedBubble(
        key: ValueKey(
            '${_messages[i].role}_${_messages[i].timestamp.millisecondsSinceEpoch}'),
        child: _buildBubble(_messages[i]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF4F7FFF), Color(0xFF9B6FFF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F7FFF).withOpacity(0.3),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '✦',
                style: TextStyle(fontSize: 34, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Start the conversation',
            style: TextStyle(
              color: Color(0xFF1A1D2E),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask me anything — I\'m here to help.',
            style: TextStyle(color: _subtleText, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _BotAvatar(),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? _userBubble : _botBubble,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isUser
                            ? const Color(0xFF4F7FFF).withOpacity(0.25)
                            : Colors.black.withOpacity(0.07),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border:
                        isUser ? null : Border.all(color: _divider, width: 1.2),
                  ),
                  child: isUser
                      ? Text(
                          msg.message,
                          style: const TextStyle(
                            color: _textOnUser,
                            fontSize: 15,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                      : MarkdownBody(
                          data: msg.message,
                          styleSheet: _mdStyle(),
                        ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatTime(msg.timestamp),
                  style: const TextStyle(
                    color: _subtleText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            _UserAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _BotAvatar(),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: _botBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: _divider, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 12,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: _inputBarBg,
        border: const Border(top: BorderSide(color: _divider, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: _inputFieldBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _inputController,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(
                  color: _textOnBot,
                  fontSize: 15,
                  height: 1.45,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ask anything…',
                  hintStyle: TextStyle(color: _subtleText, fontSize: 15),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLoading ? _sendInactive : _sendActive,
                boxShadow: _isLoading
                    ? []
                    : [
                        BoxShadow(
                          color: _sendActive.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _mdStyle() {
    return MarkdownStyleSheet(
      p: const TextStyle(
        color: _textOnBot,
        fontSize: 15,
        height: 1.55,
      ),
      code: TextStyle(
        color: const Color(0xFF4F7FFF),
        backgroundColor: const Color(0xFFEEF2FF),
        fontSize: 13.5,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF3F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _divider),
      ),
      codeblockPadding: const EdgeInsets.all(14),
      strong: const TextStyle(
        color: _textOnBot,
        fontWeight: FontWeight.w700,
      ),
      em: const TextStyle(
        color: Color(0xFF6B7280),
        fontStyle: FontStyle.italic,
      ),
      h1: const TextStyle(
        color: _textOnBot,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      h2: const TextStyle(
        color: _textOnBot,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      h3: const TextStyle(
        color: _textOnBot,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      listBullet: const TextStyle(color: Color(0xFF4F7FFF)),
      blockquoteDecoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFF4F7FFF), width: 3),
        ),
        color: Color(0xFFEEF2FF),
      ),
      blockquote: const TextStyle(
        color: Color(0xFF6B7280),
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

// ─── Avatars ──────────────────────────────────────────────────────────────────

class _BotAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF4F7FFF), Color(0xFF9B6FFF)],
        ),
      ),
      child: const Center(
        child: Text('✦', style: TextStyle(fontSize: 14, color: Colors.white)),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE8ECF4),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 18,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}

// ─── Typing Dots ──────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> {
  Timer? _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 360), (_) {
      if (mounted) setState(() => _step = (_step + 1) % 3);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final active = _step == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 9 : 7,
          height: active ? 9 : 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xFF4F7FFF) : const Color(0xFFCDD3E0),
          ),
        );
      }),
    );
  }
}

// ─── Animated Bubble Wrapper ──────────────────────────────────────────────────

class _AnimatedBubble extends StatefulWidget {
  final Widget child;

  const _AnimatedBubble({required this.child, super.key});

  @override
  State<_AnimatedBubble> createState() => _AnimatedBubbleState();
}

class _AnimatedBubbleState extends State<_AnimatedBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class CenterRightFabLocation extends FloatingActionButtonLocation {
  const CenterRightFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final scaffoldSize = scaffoldGeometry.scaffoldSize;
    final fabSize = scaffoldGeometry.floatingActionButtonSize;

    final double x = scaffoldSize.width - fabSize.width - 16; // right margin
    final double y =
        (scaffoldSize.height - fabSize.height) / 2; // vertical center

    return Offset(x, y);
  }
}
