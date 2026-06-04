import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
  });

  final String text;
  final bool isUser;
  final bool isStreaming;

  ChatMessage copyWith({String? text, bool? isUser, bool? isStreaming}) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = <ChatMessage>[
    const ChatMessage(isUser: false, text: '안녕하세요. 무엇을 도와드릴까요?'),
    const ChatMessage(isUser: true, text: 'Flutter로 채팅 UI를 만들어보고 싶어요.'),
    const ChatMessage(isUser: false, text: '좋습니다. 화면 구조부터 깔끔하게 잡아둘게요.'),
  ];

  ChatSession? _chatSession;
  bool _isTyping = false;
  bool _isUsingFallback = false;
  StreamSubscription<GenerateContentResponse>? _streamSubscription;
  bool _isStreamingInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _initializeChat();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _initializeChat() async {
    if (Firebase.apps.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isUsingFallback = true;
      });
      return;
    }

    try {
      final GenerativeModel model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-3-flash-preview',
        systemInstruction: Content.system('너는 시크한 고양이야, 항상 냐용 으로 말을 끝내도록해줘.'),
      );

      final List<Content> history = _messages
          .map(
            (ChatMessage message) => message.isUser
                ? Content.text(message.text)
                : Content.model(<Part>[TextPart(message.text)]),
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _chatSession = model.startChat(history: history);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isUsingFallback = true;
      });
    }
  }

  void _updateMessage(int index, ChatMessage message) {
    setState(() {
      _messages[index] = message;
    });
  }

  String _mergeStreamText(String previous, String incoming) {
    if (incoming.isEmpty) {
      return previous;
    }

    if (incoming.startsWith(previous)) {
      return incoming;
    }

    if (previous.startsWith(incoming)) {
      return previous;
    }

    return '$previous$incoming';
  }

  Future<void> _sendWithFallback(String text) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }

    final String reply = text.endsWith('?')
        ? '현재는 Firebase 연결이 없어서 로컬 응답으로 보여주고 있어요.'
        : '메시지를 받았어요. Firebase 초기화가 완료되면 실시간 응답으로 바뀝니다.';

    setState(() {
      _isTyping = false;
      _messages.add(ChatMessage(text: reply, isUser: false));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _cancelStreaming() {
    if (_streamSubscription == null) {
      return;
    }

    _streamSubscription?.cancel();
    _streamSubscription = null;

    if (!mounted) return;

    setState(() {
      _isStreamingInProgress = false;
      _isTyping = false;
      // Mark last assistant message as finalized with a note.
      if (_messages.isNotEmpty) {
        final int lastIndex = _messages.length - 1;
        final ChatMessage last = _messages[lastIndex];
        _messages[lastIndex] = last.copyWith(
          isStreaming: false,
          text: last.text.isEmpty ? '응답이 중단되었습니다.' : '${last.text}\n(중단됨)',
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final String text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
      _textController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    if (_chatSession == null || _isUsingFallback) {
      await _sendWithFallback(text);
      return;
    }

    final int assistantIndex = _messages.length;
    setState(() {
      _messages.add(
        const ChatMessage(text: '', isUser: false, isStreaming: true),
      );
      _isTyping = false;
    });

    String accumulatedText = '';
    var revealedAssistantMessage = false;
    final Completer<void> streamDone = Completer<void>();

    try {
      _isStreamingInProgress = true;
      final Stream<GenerateContentResponse> stream = _chatSession!
          .sendMessageStream(Content.text(text));

      _streamSubscription = stream.listen(
        (GenerateContentResponse response) {
          final String chunkText = response.text ?? '';
          if (chunkText.isEmpty) return;

          accumulatedText = _mergeStreamText(accumulatedText, chunkText);

          if (!revealedAssistantMessage) {
            revealedAssistantMessage = true;
            if (mounted) {
              setState(() {
                _isTyping = false;
              });
            }
          }

          if (mounted) {
            _updateMessage(
              assistantIndex,
              _messages[assistantIndex].copyWith(
                text: accumulatedText,
                isStreaming: true,
              ),
            );

            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToBottom(),
            );
          }
        },
        onDone: () {
          if (!mounted) {
            streamDone.complete();
            return;
          }

          if (accumulatedText.isEmpty) {
            _updateMessage(
              assistantIndex,
              const ChatMessage(
                text: '응답이 비어 있습니다. 다시 시도해 주세요.',
                isUser: false,
              ),
            );
          } else {
            _updateMessage(
              assistantIndex,
              _messages[assistantIndex].copyWith(isStreaming: false),
            );
          }

          if (mounted) {
            setState(() {
              _isStreamingInProgress = false;
            });
          }

          streamDone.complete();
        },
        onError: (e) {
          if (!mounted) {
            streamDone.completeError(e);
            return;
          }

          setState(() {
            _isTyping = false;
            _isStreamingInProgress = false;
            _messages[assistantIndex] = const ChatMessage(
                text: 'Gemini 응답을 가져오지 못했습니다. Firebase 설정을 확인해 주세요.',
              isUser: false,
            );
          });

          streamDone.completeError(e);
        },
      );

      await streamDone.future;
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isTyping = false;
        _isStreamingInProgress = false;
        _messages[assistantIndex] = const ChatMessage(
          text: 'Gemini 응답을 가져오지 못했습니다. Firebase 설정을 확인해 주세요.',
          isUser: false,
        );
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Gemini AI',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Row(
                    children: <Widget>[
                      Icon(Icons.circle, size: 10, color: Color(0xFF22C55E)),
                      SizedBox(width: 6),
                      Text(
                        '온라인',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF16A34A),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (BuildContext context, int index) {
                    if (_isTyping && index == _messages.length) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: _TypingBubble(),
                      );
                    }

                    final ChatMessage message = _messages[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: message.isUser
                          ? _UserMessageBubble(text: message.text)
                          : _AiMessageBubble(
                              text: message.text,
                              isStreaming: message.isStreaming,
                            ),
                    );
                  },
                ),
              ),
              _InputBar(
                controller: _textController,
                onSend: _handleSend,
                onCancel: _cancelStreaming,
                isStreaming: _isStreamingInProgress,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  const _UserMessageBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(
              20,
            ).copyWith(bottomRight: const Radius.circular(6)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x1A2563EB),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white, height: 1.35),
          ),
        ),
      ),
    );
  }
}

class _AiMessageBubble extends StatelessWidget {
  const _AiMessageBubble({required this.text, this.isStreaming = false});

  final String text;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.smart_toy_outlined,
            size: 18,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                20,
              ).copyWith(bottomLeft: const Radius.circular(6)),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF0F172A),
                height: 1.35,
                fontStyle: isStreaming ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ),
        if (isStreaming) ...<Widget>[
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
          ),
        ],
      ],
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.smart_toy_outlined,
            size: 18,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              20,
            ).copyWith(bottomLeft: const Radius.circular(6)),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(3, (int index) {
              final Animation<double> scaleAnimation =
                  Tween<double>(begin: 0.7, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Interval(
                        index * 0.18,
                        0.54 + index * 0.18,
                        curve: Curves.easeInOut,
                      ),
                    ),
                  );

              return Padding(
                padding: EdgeInsets.only(right: index == 2 ? 0 : 5),
                child: ScaleTransition(
                  scale: scaleAnimation,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    this.onCancel,
    this.isStreaming = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onCancel;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 52,
              height: 52,
              child: isStreaming
                  ? ElevatedButton(
                      onPressed: onCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: EdgeInsets.zero,
                        elevation: 2,
                      ),
                      child: const Icon(Icons.stop_rounded, size: 22),
                    )
                  : ElevatedButton(
                      onPressed: onSend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: EdgeInsets.zero,
                        elevation: 2,
                      ),
                      child: const Icon(Icons.send_rounded, size: 22),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
