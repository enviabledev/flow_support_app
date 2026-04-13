import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/conversation.dart';
import '../models/message.dart';

class CacheService {
  static Database? _db;

  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'enviable_cache.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            data TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_conversation ON messages(conversation_id)',
        );
        await db.execute(
          'CREATE INDEX idx_messages_created ON messages(conversation_id, created_at DESC)',
        );
      },
    );
  }

  // Conversations
  Future<void> cacheConversations(List<Conversation> conversations) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('conversations');
    for (final conv in conversations) {
      batch.insert(
        'conversations',
        {
          'id': conv.id,
          'data': jsonEncode(conv.toJson()),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Conversation>> getCachedConversations() async {
    final db = await database;
    final rows = await db.query('conversations', orderBy: 'updated_at DESC');
    return rows.map((row) {
      final json = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return Conversation.fromJson(json);
    }).toList();
  }

  // Messages
  Future<void> cacheMessages(String conversationId, List<Message> messages) async {
    final db = await database;
    final batch = db.batch();
    for (final msg in messages) {
      batch.insert(
        'messages',
        {
          'id': msg.id,
          'conversation_id': conversationId,
          'data': jsonEncode(msg.toJson()),
          'created_at': msg.createdAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Message>> getCachedMessages(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at DESC',
      limit: 50,
    );
    return rows.map((row) {
      final json = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return Message.fromJson(json);
    }).toList();
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('conversations');
    await db.delete('messages');
  }
}
