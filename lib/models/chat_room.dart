import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  const ChatRoom({
    required this.roomId,
    required this.title,
    required this.preview,
    required this.date,
    this.createdAt,
    this.updatedAt,
    this.lastMessage,
    this.lastMessageAt,
  });

  final String roomId;
  final String title;
  final String preview;
  final String date;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  factory ChatRoom.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    return ChatRoom(
      roomId: snapshot.id,
      title: data['title'] as String? ?? '',
      preview: data['preview'] as String? ?? '',
      date: data['date'] as String? ?? '',
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: _toDateTime(data['lastMessageAt']),
    );
  }

  Map<String, Object?> toFirestore() {
    return <String, Object?>{
      'title': title,
      'preview': preview,
      'date': date,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt,
    };
  }

  ChatRoom copyWith({
    String? roomId,
    String? title,
    String? preview,
    String? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    DateTime? lastMessageAt,
  }) {
    return ChatRoom(
      roomId: roomId ?? this.roomId,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
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
