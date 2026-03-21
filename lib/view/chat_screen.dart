import 'dart:async';
import 'dart:math' as math;

import 'package:chat_app/Cubit/search_cubit.dart';
import 'package:chat_app/Cubit/search_state.dart';
import 'package:chat_app/controller/auth_services.dart';
import 'package:chat_app/view/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ─── Design Tokens ────────────────────────────────────────────────────────────

class _T {
  // Backgrounds
  static const bg = Color(0xFF0D0F14);
  static const surface = Color(0xFF13161E);
  static const surfaceElevated = Color(0xFF1A1E2A);
  static const surfaceHigh = Color(0xFF222636);

  // Accent – warm rose-coral
  static const accent = Color(0xFFFF5B7A);
  static const accentGlow = Color(0x44FF5B7A);
  static const accentSoft = Color(0xFFFF8FA3);

  // User bubble – rose → amber warm gradient
  static const userBubbleStart = Color(0xFFFF416C);
  static const userBubbleEnd = Color(0xFFFF9A3C);

  // Text
  static const textPrimary = Color(0xFFECEEF4);
  static const textSecondary = Color(0xFF8890A8);
  static const textMuted = Color(0xFF4E566A);

  // Borders / dividers
  static const border = Color(0xFF252A38);
  static const borderBright = Color(0xFF323850);

  // Status
  static const online = Color(0xFF3DD68C);
  static const thinking = Color(0xFFF5A623);
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final CollectionReference _chatsRef =
      FirebaseFirestore.instance.collection('chats');

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isClearing = false;
  bool _inputHasText = false;
  String? _pendingQuery;
  StreamSubscription<QuerySnapshot>? _sub;

  // Page-load entrance animation
  late final AnimationController _pageEntryCtrl;
  late final Animation<double> _pageEntryAnim;

  @override
  void initState() {
    super.initState();
    _pageEntryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pageEntryAnim = CurvedAnimation(
      parent: _pageEntryCtrl,
      curve: Curves.easeOutCubic,
    );
    _pageEntryCtrl.forward();

    _inputController.addListener(() {
      final has = _inputController.text.trim().isNotEmpty;
      if (has != _inputHasText) setState(() => _inputHasText = has);
    });

    _listenToFirestore();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _sub?.cancel();
    _pageEntryCtrl.dispose();
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

    HapticFeedback.lightImpact();
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
          duration: const Duration(milliseconds: 420),
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
      for (final doc in snap.docs) batch.delete(doc.reference);
      await batch.commit();
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to clear: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  void _confirmClear() {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: Tween(begin: 0.88, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => _ClearDialog(
        onConfirm: () async {
          Navigator.pop(ctx);
          await _clearAllMessages();
          if (mounted) _showSnack('Conversation cleared', isError: false);
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  void _confirmLogout() {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: Tween(begin: 0.88, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => _LogoutDialog(
        onConfirm: () async {
          Navigator.pop(ctx);
          // ── calls AuthService — no auth logic lives here ──
          final error = await AuthService.instance.logout();
          if (error != null && mounted) {
            _showSnack(error, isError: true);
          } else if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: _T.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? const Color(0xFF7B2D2D) : _T.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: const Duration(seconds: 2),
        elevation: 0,
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
          _showSnack(state.errorMsg, isError: true);
        }
      },
      child: Scaffold(
        backgroundColor: _T.bg,
        extendBodyBehindAppBar: false,
        appBar: _buildAppBar(),
        body: FadeTransition(
          opacity: _pageEntryAnim,
          child: Column(
            children: [
              Expanded(child: _buildList()),
              if (_isLoading) _buildTypingBubble(),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          color: _T.surface,
          border: const Border(
            bottom: BorderSide(color: _T.border, width: 1),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with animated glow ring
                _PulsingAvatar(isActive: _isLoading),
                const SizedBox(width: 14),
                // Title + status — takes all remaining space
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Smarty AI',
                        style: TextStyle(
                          color: _T.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.4),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _StatusRow(
                          key: ValueKey(_isLoading),
                          isLoading: _isLoading,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right-side buttons — fixed width, never expand
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_messages.isNotEmpty) ...[
                      _isClearing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _T.textMuted,
                              ),
                            )
                          : _AppBarButton(
                              icon: Icons.auto_delete_outlined,
                              onTap: _confirmClear,
                              tooltip: 'Clear chat',
                            ),
                      const SizedBox(width: 8),
                    ],
                    _AppBarButton(
                      icon: Icons.logout_rounded,
                      onTap: _confirmLogout,
                      tooltip: 'Logout',
                      isDestructive: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Message List ───────────────────────────────────────────────────────────

  Widget _buildList() {
    if (_messages.isEmpty && !_isLoading) {
      return FadeTransition(
        opacity: _pageEntryAnim,
        child: const _EmptyState(),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        final prevMsg = i > 0 ? _messages[i - 1] : null;
        final isFirstInGroup = prevMsg == null || prevMsg.role != msg.role;

        return _AnimatedBubble(
          key: ValueKey('${msg.role}_${msg.timestamp.millisecondsSinceEpoch}'),
          child: _buildBubble(msg, isFirstInGroup: isFirstInGroup),
        );
      },
    );
  }

  Widget _buildBubble(_ChatMessage msg, {required bool isFirstInGroup}) {
    final isUser = msg.isUser;

    return Padding(
      padding: EdgeInsets.only(bottom: isFirstInGroup ? 4 : 3),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bot avatar — only show on first in group
          if (!isUser)
            isFirstInGroup
                ? Padding(
                    padding: const EdgeInsets.only(right: 10, bottom: 2),
                    child: _BotAvatar(),
                  )
                : const SizedBox(width: 42),

          // Bubble
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _BubbleBody(msg: msg, isFirstInGroup: isFirstInGroup),
                const SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.only(
                    left: isUser ? 0 : 2,
                    right: isUser ? 2 : 0,
                  ),
                  child: Text(
                    _formatTime(msg.timestamp),
                    style: const TextStyle(
                      color: _T.textMuted,
                      fontSize: 10.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isUser) const SizedBox(width: 6),
        ],
      ),
    );
  }

  // ── Typing Indicator ───────────────────────────────────────────────────────

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _BotAvatar(),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: _T.surfaceElevated,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: _T.border, width: 1),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  // ── Input Bar ──────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottom + 10),
      decoration: BoxDecoration(
        color: _T.surface,
        border: const Border(top: BorderSide(color: _T.border, width: 1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(maxHeight: 130),
              decoration: BoxDecoration(
                color: _T.surfaceElevated,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _inputFocus.hasFocus || _inputHasText
                      ? _T.borderBright
                      : _T.border,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocus,
                minLines: 1,
                maxLines: null,
                expands: false,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                onTap: () => setState(() {}),
                style: const TextStyle(
                  color: _T.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Ask anything…',
                  hintStyle: TextStyle(
                    color: _T.textMuted,
                    fontSize: 15,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 46,
            height: 46,
            child: _SendButton(
              hasText: _inputHasText,
              isLoading: _isLoading,
              onTap: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bubble Body ──────────────────────────────────────────────────────────────

class _BubbleBody extends StatelessWidget {
  final _ChatMessage msg;
  final bool isFirstInGroup;

  const _BubbleBody({required this.msg, required this.isFirstInGroup});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    final maxWidth = MediaQuery.of(context).size.width * 0.74;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(
                colors: [_T.userBubbleStart, _T.userBubbleEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isUser ? null : _T.surfaceElevated,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
        border: isUser ? null : Border.all(color: _T.border, width: 1),
        boxShadow: isUser
            ? [
                BoxShadow(
                  color: _T.userBubbleStart.withOpacity(0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: isUser
          ? SelectableText(
              msg.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.74,
                ),
                child: MarkdownBody(
                  data: msg.message,
                  styleSheet: _mdStyleSheet(),
                  selectable: true,
                ),
              ),
            ),
    );
  }

  MarkdownStyleSheet _mdStyleSheet() {
    return MarkdownStyleSheet(
      p: const TextStyle(
        color: _T.textPrimary,
        fontSize: 15,
        height: 1.6,
      ),
      code: TextStyle(
        color: _T.accentSoft,
        backgroundColor: const Color(0xFF1E2235),
        fontSize: 13,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFF141825),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _T.border, width: 1),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      strong:
          const TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w700),
      em: const TextStyle(color: _T.textSecondary, fontStyle: FontStyle.italic),
      h1: const TextStyle(
          color: _T.textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
      h2: const TextStyle(
          color: _T.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      h3: const TextStyle(
          color: _T.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
      listBullet: const TextStyle(color: _T.accentSoft),
      blockquoteDecoration: BoxDecoration(
        color: const Color(0xFF1A1E2E),
        border: const Border(left: BorderSide(color: _T.accent, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      blockquote:
          const TextStyle(color: _T.textSecondary, fontStyle: FontStyle.italic),
    );
  }
}

// ─── Pulsing Avatar (App Bar) ─────────────────────────────────────────────────

class _PulsingAvatar extends StatefulWidget {
  final bool isActive;
  const _PulsingAvatar({required this.isActive});

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        final ringOpacity = widget.isActive ? (_pulse.value * 0.5) : 0.0;
        final ringSize = widget.isActive ? (44 + _pulse.value * 8) : 44.0;
        return SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow ring
              Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _T.accent.withOpacity(ringOpacity),
                    width: 1.5,
                  ),
                ),
              ),
              // Avatar
              ClipOval(
                child: Image.asset(
                  'assets/images/SmartMateAI.jpeg',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Status Row ───────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final bool isLoading;
  const _StatusRow({required this.isLoading, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLoading ? _T.thinking : _T.online,
            boxShadow: [
              BoxShadow(
                color: (isLoading ? _T.thinking : _T.online).withOpacity(0.6),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          isLoading ? 'Thinking…' : 'Online',
          style: TextStyle(
            color: isLoading ? _T.thinking : _T.online,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ─── App Bar Icon Button ──────────────────────────────────────────────────────

class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool isDestructive;

  const _AppBarButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isDestructive ? const Color(0xFFFF5B7A) : _T.textSecondary;
    final borderColor = isDestructive ? const Color(0xFF3D1E28) : _T.border;
    final bgColor =
        isDestructive ? const Color(0xFF1E1218) : _T.surfaceElevated;
    final splashColor = isDestructive ? const Color(0x33FF5B7A) : _T.accentGlow;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: splashColor,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1),
              color: bgColor,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatefulWidget {
  const _EmptyState();

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _float,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _float.value),
              child: child,
            ),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _T.accent.withOpacity(0.25),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/SmartMateAI.jpeg',
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Smarty AI',
            style: TextStyle(
              color: _T.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask me anything — I\'m here to help.',
            style: TextStyle(
              color: _T.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 36),
          // Suggestion chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: const [
              _SuggestionChip(label: '✦ Explain a concept'),
              _SuggestionChip(label: '⚡ Write some code'),
              _SuggestionChip(label: '🔍 Summarize text'),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Suggestion Chips ─────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String label;
  const _SuggestionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: _T.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.borderBright, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _T.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Send Button ──────────────────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  final bool hasText;
  final bool isLoading;
  final VoidCallback onTap;

  const _SendButton({
    required this.hasText,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canSend = hasText && !isLoading;

    return GestureDetector(
      onTap: canSend ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: canSend ? _T.accent : _T.surfaceElevated,
          boxShadow: canSend
              ? [
                  BoxShadow(
                    color: _T.accent.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
          border: Border.all(
            color: canSend ? Colors.transparent : _T.border,
            width: 1,
          ),
        ),
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: canSend ? 1.0 : 0.9,
            child: Icon(
              Icons.send_rounded,
              size: 20,
              color: canSend ? Colors.white : _T.textMuted,
            ),
          ),
        ),
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _T.accent.withOpacity(0.20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/SmartMateAI.jpeg',
          width: 32,
          height: 32,
          fit: BoxFit.cover,
        ),
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

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot by 0.2 of the cycle; use modulo to wrap
            final offset = ((_ctrl.value - i * 0.2) % 1.0);
            // Normalize sin to [0,1] — always non-negative
            final normalized = (math.sin(offset * math.pi * 2) + 1.0) / 2.0;
            final scale = 0.75 + normalized * 0.5; // [0.75 … 1.25]
            final opacity = 0.3 + normalized * 0.7; // [0.30 … 1.00]
            final yShift = -normalized * 5.0; // bounce up by up to 5px

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, yShift),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _T.accentSoft,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
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
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
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
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

// ─── Clear Dialog ─────────────────────────────────────────────────────────────

class _ClearDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ClearDialog({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _T.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon badge
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF2E1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF5C2828), width: 1),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFFF6B6B),
                size: 22,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Clear conversation?',
              style: TextStyle(
                color: _T.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All messages will be permanently deleted from Firebase. This action cannot be undone.',
              style: TextStyle(
                color: _T.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _T.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _T.border, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _T.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B2D2D),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4444).withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: Color(0xFFFFB3B3),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logout Dialog ────────────────────────────────────────────────────────────

class _LogoutDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _LogoutDialog({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _T.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon badge
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1218),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3D1E28),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFFF5B7A),
                size: 22,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Log out?',
              style: TextStyle(
                color: _T.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You\'ll be signed out of your account. You can log back in anytime.',
              style: TextStyle(
                color: _T.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Cancel
                Expanded(
                  child: GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _T.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _T.border, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _T.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Confirm logout
                Expanded(
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF416C), Color(0xFFFF9A3C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF416C).withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Log out',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
