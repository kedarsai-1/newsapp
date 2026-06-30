import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../utils/ai_chat_response.dart';
import '../../utils/i18n.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// AI Chat screen with modern glass morphism design.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  List<Map<String, String>> _historyPayload() {
    final rows = <Map<String, String>>[];
    for (final msg in _messages) {
      if (msg.text.trim().isEmpty) continue;
      rows.add({'role': msg.isUser ? 'user' : 'assistant', 'content': msg.text});
    }
    if (rows.length > 8) {
      return rows.sublist(rows.length - 8);
    }
    return rows;
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/feed');
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _loading) return;

    final news = context.read<NewsProvider>();
    final language = news.selectedLanguage == 'all'
        ? (news.shortsFeedLanguage ?? 'en')
        : news.selectedLanguage;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _loading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    final res = await ApiService.chatWithAi(
      message: text,
      language: language,
      city: news.preferredCity,
      history: _historyPayload(),
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final parsed = AiChatResponse.fromJson(res);
      setState(() {
        _messages.add(
          _ChatMessage(
            text: parsed.answer.trim().isEmpty
                ? 'I could not find an answer. Try rephrasing your question.'
                : parsed.answer,
            isUser: false,
            relatedArticles: parsed.relatedArticles,
          ),
        );
        _loading = false;
      });
    } else {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: res['message']?.toString() ??
                'AI chat is unavailable right now. Please try again.',
            isUser: false,
            isError: true,
          ),
        );
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: fx.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Modern Header ──────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                decoration: BoxDecoration(
                  color: fx.background,
                  border: Border(
                    bottom: BorderSide(color: fx.divider, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: fx.iconFg),
                      onPressed: _handleBack,
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            fx.accent,
                            fx.accentTertiary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: fx.accent.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            I18n.t(context, 'ai_chat_title'),
                            style: GoogleFonts.notoSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: fx.title,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: fx.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'AI Assistant',
                                style: GoogleFonts.notoSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: fx.actionMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Messages ──────────────────────────────────────
              Expanded(
                child: _messages.isEmpty
                    ? _EmptyPrompt(onTap: _send)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: _messages.length + (_loading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _messages.length) {
                            return _TypingIndicator(fx: fx);
                          }
                          return _MessageBubble(
                            message: _messages[index],
                            onOpenArticle: (id) => context.push('/article/$id'),
                          );
                        },
                      ),
              ),

              // ── Input Bar ──────────────────────────────────────
              _InputBar(
                controller: _inputController,
                loading: _loading,
                onSend: () => _send(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final dynamic fx;

  const _TypingIndicator({required this.fx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: fx.iconSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: fx.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(color: fx.accent, delay: 0),
                const SizedBox(width: 4),
                _Dot(color: fx.accent, delay: 0.2),
                const SizedBox(width: 4),
                _Dot(color: fx.accent, delay: 0.4),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            I18n.t(context, 'ai_chat_thinking'),
            style: GoogleFonts.notoSans(
              color: fx.actionMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final dynamic color;
  final double delay;

  const _Dot({required this.color, required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) {
        _ctrl.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.4 + (_anim.value * 0.6)),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final List<AiChatRelatedArticle> relatedArticles;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.relatedArticles = const [],
  });
}

class _EmptyPrompt extends StatelessWidget {
  final void Function(String) onTap;

  const _EmptyPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final prompts = [
      I18n.t(context, 'ai_chat_prompt_headlines'),
      I18n.t(context, 'ai_chat_prompt_sports'),
      I18n.t(context, 'ai_chat_prompt_weather'),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Hero illustration
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  fx.accent.withValues(alpha: 0.15),
                  fx.accentTertiary.withValues(alpha: 0.15),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: fx.accent.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 48,
                  color: fx.accent,
                ),
                Positioned(
                  right: 18,
                  top: 18,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: fx.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: fx.accent.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.chat_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            I18n.t(context, 'ai_chat_empty_title'),
            style: GoogleFonts.notoSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: fx.title,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            I18n.t(context, 'ai_chat_empty_subtitle'),
            style: GoogleFonts.notoSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: fx.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Prompt suggestions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: fx.glassSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: fx.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: fx.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Try asking',
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: fx.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...prompts.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PromptChip(
                      label: p,
                      icon: _iconForPrompt(p),
                      onTap: () => onTap(p),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForPrompt(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('headline')) return Icons.newspaper_rounded;
    if (lower.contains('sport')) return Icons.sports_cricket_rounded;
    if (lower.contains('weather')) return Icons.wb_sunny_rounded;
    return Icons.search_rounded;
  }
}

class _PromptChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PromptChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_PromptChip> createState() => _PromptChipState();
}

class _PromptChipState extends State<_PromptChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: fx.iconSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: fx.divider),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: fx.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fx.iconFg,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: fx.actionMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final void Function(String id) onOpenArticle;

  const _MessageBubble({
    required this.message,
    required this.onOpenArticle,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final isUser = message.isUser;
    final isError = message.isError;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [fx.accent, fx.accentTertiary],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? fx.accent.withValues(alpha: 0.15)
                    : isError
                        ? fx.errorSurface
                        : fx.glassSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: Border.all(
                  color: isUser
                      ? fx.accent.withValues(alpha: 0.2)
                      : fx.glassBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: fx.heroShadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: fx.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI Assistant',
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: fx.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    message.text,
                    style: GoogleFonts.notoSans(
                      color: isError ? fx.error : fx.iconFg,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (message.relatedArticles.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: fx.divider),
                    const SizedBox(height: 12),
                    Text(
                      I18n.t(context, 'ai_chat_related_stories'),
                      style: GoogleFonts.notoSans(
                        color: fx.actionMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...message.relatedArticles.take(3).map(
                          (a) => _RelatedArticleTile(
                            article: a,
                            onTap: () => onOpenArticle(a.id),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: fx.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RelatedArticleTile extends StatefulWidget {
  final AiChatRelatedArticle article;
  final VoidCallback onTap;

  const _RelatedArticleTile({
    required this.article,
    required this.onTap,
  });

  @override
  State<_RelatedArticleTile> createState() => _RelatedArticleTileState();
}

class _RelatedArticleTileState extends State<_RelatedArticleTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fx.iconSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fx.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSans(
                        color: fx.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (widget.article.sourceName != null &&
                        widget.article.sourceName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.article.sourceName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSans(
                          color: fx.actionMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: fx.actionMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.loading,
    required this.onSend,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: fx.background,
        border: Border(
          top: BorderSide(color: fx.divider, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: fx.glassSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: fx.glassBorder),
                  boxShadow: [
                    BoxShadow(
                      color: fx.heroShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onSend(),
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    color: fx.iconFg,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: I18n.t(context, 'ai_chat_input_hint'),
                    hintStyle: GoogleFonts.notoSans(
                      fontSize: 14,
                      color: fx.actionMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.loading || !_hasText ? null : widget.onSend,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: _hasText && !widget.loading
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [fx.accent, fx.accentTertiary],
                            )
                          : null,
                      color: !_hasText || widget.loading
                          ? fx.iconSurface
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _hasText && !widget.loading
                          ? [
                              BoxShadow(
                                color: fx.accent.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: widget.loading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: fx.actionMuted,
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: _hasText
                                  ? Colors.white
                                  : fx.actionMuted,
                              size: 22,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
