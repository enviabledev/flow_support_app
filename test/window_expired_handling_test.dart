import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/message.dart';
import 'package:mobile/models/conversation.dart';
import 'package:mobile/models/contact.dart';

void main() {
  group('Message.isUndelivered', () {
    test('returns true when status is undelivered', () {
      final msg = Message(
        id: '1',
        conversationId: 'conv-1',
        direction: 'outbound',
        senderType: 'staff',
        status: 'undelivered',
        createdAt: DateTime.now(),
      );
      expect(msg.isUndelivered, isTrue);
    });

    test('returns false for sent status', () {
      final msg = Message(
        id: '1',
        conversationId: 'conv-1',
        direction: 'outbound',
        senderType: 'staff',
        status: 'sent',
        createdAt: DateTime.now(),
      );
      expect(msg.isUndelivered, isFalse);
    });

    test('returns false for delivered status', () {
      final msg = Message(
        id: '1',
        conversationId: 'conv-1',
        direction: 'outbound',
        senderType: 'staff',
        status: 'delivered',
        createdAt: DateTime.now(),
      );
      expect(msg.isUndelivered, isFalse);
    });

    test('returns false for failed status', () {
      final msg = Message(
        id: '1',
        conversationId: 'conv-1',
        direction: 'outbound',
        senderType: 'staff',
        status: 'failed',
        createdAt: DateTime.now(),
      );
      expect(msg.isUndelivered, isFalse);
    });
  });

  group('Message.copyWith status', () {
    test('can update status to undelivered', () {
      final msg = Message(
        id: '1',
        conversationId: 'conv-1',
        direction: 'outbound',
        senderType: 'staff',
        status: 'queued',
        createdAt: DateTime.now(),
        isOptimistic: true,
      );

      final updated = msg.copyWith(status: 'undelivered');
      expect(updated.status, 'undelivered');
      expect(updated.isUndelivered, isTrue);
      expect(updated.id, '1');
      expect(updated.isOptimistic, isTrue);
    });
  });

  group('24h Window Check Logic', () {
    bool isWindowExpired(DateTime? lastInboundAt) {
      if (lastInboundAt == null) return true;
      return DateTime.now().toUtc().difference(lastInboundAt).inHours >= 23;
    }

    test('expired when lastInboundAt is null', () {
      expect(isWindowExpired(null), isTrue);
    });

    test('expired when last inbound was 24 hours ago', () {
      final old = DateTime.now().toUtc().subtract(const Duration(hours: 24));
      expect(isWindowExpired(old), isTrue);
    });

    test('expired when last inbound was 23 hours ago', () {
      final old = DateTime.now().toUtc().subtract(const Duration(hours: 23));
      expect(isWindowExpired(old), isTrue);
    });

    test('NOT expired when last inbound was 22 hours ago', () {
      final recent = DateTime.now().toUtc().subtract(const Duration(hours: 22));
      expect(isWindowExpired(recent), isFalse);
    });

    test('NOT expired when last inbound was 1 minute ago', () {
      final recent = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      expect(isWindowExpired(recent), isFalse);
    });

    test('NOT expired when last inbound was just now', () {
      final now = DateTime.now().toUtc();
      expect(isWindowExpired(now), isFalse);
    });
  });

  group('Conversation.lastInboundAt parsing', () {
    test('parses lastInboundAt from JSON', () {
      final json = {
        'id': 'conv-1',
        'contact': {
          'id': 'ct-1',
          'phoneNumber': '+1234567890',
        },
        'lastInboundAt': '2026-04-13T12:00:00.000Z',
      };

      final conv = Conversation.fromJson(json);
      expect(conv.lastInboundAt, isNotNull);
      expect(conv.lastInboundAt!.year, 2026);
      expect(conv.lastInboundAt!.month, 4);
      expect(conv.lastInboundAt!.day, 13);
    });

    test('handles null lastInboundAt', () {
      final json = {
        'id': 'conv-1',
        'contact': {
          'id': 'ct-1',
          'phoneNumber': '+1234567890',
        },
        'lastInboundAt': null,
      };

      final conv = Conversation.fromJson(json);
      expect(conv.lastInboundAt, isNull);
    });

    test('handles missing lastInboundAt', () {
      final json = {
        'id': 'conv-1',
        'contact': {
          'id': 'ct-1',
          'phoneNumber': '+1234567890',
        },
      };

      final conv = Conversation.fromJson(json);
      expect(conv.lastInboundAt, isNull);
    });

    test('copyWith updates lastInboundAt', () {
      final json = {
        'id': 'conv-1',
        'contact': {'id': 'ct-1', 'phoneNumber': '+1234567890'},
        'lastInboundAt': null,
      };

      final conv = Conversation.fromJson(json);
      expect(conv.lastInboundAt, isNull);

      final updated = conv.copyWith(lastInboundAt: DateTime.utc(2026, 4, 13, 15, 0));
      expect(updated.lastInboundAt, isNotNull);
      expect(updated.lastInboundAt!.hour, 15);
      expect(conv.lastInboundAt, isNull);
    });
  });

  group('Broadcast expired contact detection', () {
    Conversation makeConvo(String id, DateTime? lastInboundAt) {
      return Conversation(
        id: id,
        contact: const Contact(id: 'ct-1', phoneNumber: '+1234567890', displayName: 'Test'),
        lastInboundAt: lastInboundAt,
      );
    }

    bool isExpired(Conversation convo) {
      final lastInbound = convo.lastInboundAt;
      if (lastInbound == null) return true;
      return DateTime.now().toUtc().difference(lastInbound).inHours >= 23;
    }

    test('contact with null lastInboundAt is expired', () {
      final convo = makeConvo('1', null);
      expect(isExpired(convo), isTrue);
    });

    test('contact with recent lastInboundAt is NOT expired', () {
      final convo = makeConvo('1', DateTime.now().toUtc().subtract(const Duration(hours: 1)));
      expect(isExpired(convo), isFalse);
    });

    test('contact with old lastInboundAt IS expired', () {
      final convo = makeConvo('1', DateTime.now().toUtc().subtract(const Duration(hours: 25)));
      expect(isExpired(convo), isTrue);
    });

    test('selectAll should only count non-expired', () {
      final conversations = [
        makeConvo('1', DateTime.now().toUtc().subtract(const Duration(hours: 1))),
        makeConvo('2', DateTime.now().toUtc().subtract(const Duration(hours: 25))),
        makeConvo('3', null),
        makeConvo('4', DateTime.now().toUtc().subtract(const Duration(hours: 5))),
      ];

      final nonExpiredIds = conversations
          .where((c) => !isExpired(c))
          .map((c) => c.id)
          .toSet();

      expect(nonExpiredIds, {'1', '4'});
      expect(nonExpiredIds.length, 2);
    });
  });
}
