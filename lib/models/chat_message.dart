import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    this.messageId,
    this.roomId,
    required this.text,
    required this.isUser,
    this.createdAt,
    this.isStreaming = false,
  });

  final String? messageId;
  final String? roomId;
  final String text;
  final bool isUser;
  final DateTime? createdAt;
  final bool isStreaming;

  String get role => isUser ? 'user' : 'assistant';

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    return ChatMessage(
      messageId: snapshot.id,
      roomId: data['roomId'] as String?,
      text: data['text'] as String? ?? '',
      isUser: (data['role'] as String?) != 'assistant',
      createdAt: _toDateTime(data['createdAt']),
    );
  }

  Map<String, Object?> toFirestore() {
    return <String, Object?>{
      'roomId': roomId,
      'role': role,
      'text': text,
      'createdAt': createdAt,
    };
  }

  ChatMessage copyWith({
    String? messageId,
    String? roomId,
    String? text,
    bool? isUser,
    DateTime? createdAt,
    bool? isStreaming,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      roomId: roomId ?? this.roomId,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      createdAt: createdAt ?? this.createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }
}
