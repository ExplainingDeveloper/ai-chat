import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message.dart';
import '../models/chat_room.dart';

class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('채팅을 저장하려면 로그인이 필요합니다.');
    }
    return uid;
  }

  CollectionReference<ChatRoom> get _rooms => _firestore
      .collection('users')
      .doc(_uid)
      .collection('chats')
      .withConverter<ChatRoom>(
        fromFirestore: ChatRoom.fromFirestore,
        toFirestore: (ChatRoom room, SetOptions? options) => room.toFirestore(),
      );

  CollectionReference<ChatMessage> _messages(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('messages')
        .withConverter<ChatMessage>(
          fromFirestore: ChatMessage.fromFirestore,
          toFirestore: (ChatMessage message, SetOptions? options) =>
              message.toFirestore(),
        );
  }

  Future<void> createRoom(ChatRoom room) async {
    final DateTime now = room.createdAt ?? DateTime.now();
    final DocumentReference<ChatRoom> roomRef = _rooms.doc(room.roomId);
    final DocumentSnapshot<ChatRoom> snapshot = await roomRef.get();

    if (!snapshot.exists) {
      await roomRef.set(
        room.copyWith(
          createdAt: room.createdAt ?? now,
          updatedAt: room.updatedAt ?? now,
          lastMessage: room.lastMessage ?? room.preview,
          lastMessageAt: room.lastMessageAt ?? now,
        ),
      );
      return;
    }

    await roomRef.set(
      room.copyWith(title: room.title),
      SetOptions(merge: true),
    );
  }

  Future<ChatMessage> addMessage(
    ChatMessage message, {
    bool shouldUpdateRoomSummary = true,
    String? roomTitle,
  }) async {
    final String? roomId = message.roomId;
    if (roomId == null || roomId.isEmpty) {
      throw ArgumentError('message.roomId is required');
    }

    final DateTime now = message.createdAt ?? DateTime.now();
    final ChatMessage savedMessage = message.copyWith(createdAt: now);

    final DocumentReference<ChatMessage> messageRef = await _messages(
      roomId,
    ).add(savedMessage.copyWith(roomId: roomId, createdAt: now));

    if (shouldUpdateRoomSummary) {
      await updateRoomSummary(
        roomId: roomId,
        title: roomTitle,
        preview: savedMessage.text,
        lastMessage: savedMessage.text,
        lastMessageAt: now,
        updatedAt: now,
      );
    }

    return savedMessage.copyWith(messageId: messageRef.id);
  }

  Future<void> updateMessage(ChatMessage message) async {
    final String? roomId = message.roomId;
    final String? messageId = message.messageId;
    if (roomId == null || roomId.isEmpty) {
      throw ArgumentError('message.roomId is required');
    }
    if (messageId == null || messageId.isEmpty) {
      throw ArgumentError('message.messageId is required');
    }

    await _messages(roomId)
        .doc(messageId)
        .set(message.copyWith(roomId: roomId), SetOptions(merge: true));
  }

  Future<void> updateRoomSummary({
    required String roomId,
    String? title,
    required String preview,
    required String lastMessage,
    required DateTime lastMessageAt,
    required DateTime updatedAt,
  }) async {
    final Map<String, Object?> data = <String, Object?>{
      'updatedAt': updatedAt,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt,
      'preview': preview,
    };

    if (title != null && title.trim().isNotEmpty) {
      data['title'] = title;
    }

    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('chats')
        .doc(roomId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> deleteRoom(String roomId) async {
    final QuerySnapshot<ChatMessage> messages = await _messages(roomId).get();
    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<ChatMessage> doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_rooms.doc(roomId));
    await batch.commit();
  }

  Future<List<ChatRoom>> fetchRooms() async {
    final QuerySnapshot<ChatRoom> snapshot = await _rooms
        .orderBy('updatedAt', descending: true)
        .get(const GetOptions(source: Source.serverAndCache));

    return snapshot.docs
        .map((QueryDocumentSnapshot<ChatRoom> doc) {
          final ChatRoom room = doc.data();
          return room.copyWith(roomId: doc.id);
        })
        .toList(growable: true);
  }

  Future<List<ChatMessage>> fetchMessages(String roomId) async {
    final QuerySnapshot<ChatMessage> snapshot = await _messages(
      roomId,
    ).orderBy('createdAt').get(const GetOptions(source: Source.serverAndCache));

    return snapshot.docs
        .map((QueryDocumentSnapshot<ChatMessage> doc) {
          final ChatMessage message = doc.data();
          return message.copyWith(messageId: doc.id, roomId: roomId);
        })
        .toList(growable: true);
  }
}
