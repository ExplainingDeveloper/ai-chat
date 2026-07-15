import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'models/chat_room.dart';
import 'services/chat_repository.dart';
import 'settings_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatRepository _repository = ChatRepository();

  late Future<List<ChatRoom>> _roomsFuture = _loadRooms();

  String _newRoomId() {
    return 'chat-${DateTime.now().millisecondsSinceEpoch}';
  }

  ChatRoom _createNewRoom() {
    final String roomId = _newRoomId();
    return ChatRoom(
      roomId: roomId,
      title: '새 채팅',
      preview: '메시지를 입력하면 이 방에 기록됩니다.',
      date: DateTime.now().toIso8601String().substring(0, 10),
    );
  }

  Future<void> _openChat(BuildContext context, ChatRoom room) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(roomId: room.roomId, roomTitle: room.title),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _roomsFuture = _loadRooms();
    });
  }

  Future<void> _startNewChat(BuildContext context) async {
    final ChatRoom room = _createNewRoom();
    await _openChat(context, room);
  }

  Future<List<ChatRoom>> _loadRooms() async {
    return _repository.fetchRooms();
  }

  Future<bool> _confirmDeleteRoom(BuildContext context, ChatRoom room) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('대화 삭제'),
          content: Text('"${room.title}" 대화를 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                '삭제',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return false;
    }

    try {
      await _repository.deleteRoom(room.roomId);
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제에 실패했습니다: $e')));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅 목록'),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
          ),
          IconButton(
            onPressed: () => _startNewChat(context),
            icon: const Icon(Icons.add_rounded),
            tooltip: '새 채팅 시작',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<ChatRoom>>(
        future: _roomsFuture,
        builder:
            (BuildContext context, AsyncSnapshot<List<ChatRoom>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('채팅 목록을 불러오지 못했습니다.\n${snapshot.error}'),
              ),
            );
          }

          final List<ChatRoom> rooms = snapshot.data ?? <ChatRoom>[];

          if (rooms.isEmpty) {
            return const Center(
              child: Text('아직 저장된 대화가 없습니다.\n새 채팅을 시작해 보세요.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            separatorBuilder: (BuildContext context, int index) {
              return const SizedBox(height: 12);
            },
            itemBuilder: (BuildContext context, int index) {
              final ChatRoom room = rooms[index];

              return Dismissible(
                key: ValueKey(room.roomId),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDeleteRoom(context, room),
                onDismissed: (_) {
                  setState(() {
                    rooms.removeAt(index);
                  });
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                  ),
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  elevation: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openChat(context, room),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        room.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      room.date,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF64748B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  room.preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF475569),
                                        height: 1.35,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
