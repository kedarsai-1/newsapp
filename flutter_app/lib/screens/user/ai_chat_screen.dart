import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../utils/ai_chat_response.dart';
import '../../utils/i18n.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

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
      appBar: AppBar(
        backgroundColor: fx.background,
        foregroundColor: fx.iconFg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(I18n.t(context, 'ai_chat_title'), style: fx.screenTitleStyle.copyWith(fontSize: 17)),
            Text(
              I18n.t(context, 'ai_chat_subtitle'),
              style: TextStyle(
                fontSize: 12,
                color: fx.actionMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: _handleBack,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _EmptyPrompt(onTap: _send)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _messages.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: fx.accent,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                I18n.t(context, 'ai_chat_thinking'),
                                style: TextStyle(color: fx.actionMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }
                      return _MessageBubble(
                        message: _messages[index],
                        onOpenArticle: (id) => context.push('/article/$id'),
                      );
                    },
                  ),
          ),
          _InputBar(
            controller: _inputController,
            loading: _loading,
            onSend: () => _send(),
          ),
        ],
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(Icons.auto_awesome_rounded, size: 42, color: fx.accent),
        SizedBox(height: 12),
        Text(
          I18n.t(context, 'ai_chat_empty_title'),
          style: fx.screenTitleStyle.copyWith(fontSize: 20),
        ),
        SizedBox(height: 8),
        Text(
          I18n.t(context, 'ai_chat_empty_subtitle'),
          style: TextStyle(color: fx.actionMuted, height: 1.4),
        ),
        SizedBox(height: 20),
        ...prompts.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: fx.iconFg,
                side: BorderSide(color: fx.divider),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: () => onTap(p),
              child: Text(p),
            ),
          ),
        ),
      ],
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
    final align = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = message.isUser
        ? fx.accent.withValues(alpha: 0.18)
        : message.isError
            ? fx.errorSurface
            : fx.iconSurface;
    final fg = message.isError ? fx.error : fx.iconFg;

    return Align(
      alignment: align,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fx.divider.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text, style: TextStyle(color: fg, height: 1.45)),
            if (message.relatedArticles.isNotEmpty) ...[
              SizedBox(height: 10),
              Text(
                I18n.t(context, 'ai_chat_related_stories'),
                style: TextStyle(
                  color: fx.actionMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              ...message.relatedArticles.take(3).map(
                    (a) => TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: a.id.isEmpty ? null : () => onOpenArticle(a.id),
                      child: Text(
                        a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fx.accent, fontSize: 13),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.loading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: I18n.t(context, 'ai_chat_input_hint'),
                  filled: true,
                  fillColor: fx.iconSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: fx.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: fx.divider),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            SizedBox(width: 8),
            IconButton.filled(
              onPressed: loading ? null : onSend,
              icon: Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
