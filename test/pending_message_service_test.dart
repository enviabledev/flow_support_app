import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/pending_message_service.dart';

void main() {
  late PendingMessageService service;

  setUp(() {
    service = PendingMessageService.instance;
    // Cancel all pending messages from previous tests
    service.cancelMessage(conversationId: 'conv-1');
    service.cancelMessage(conversationId: 'conv-2');
    service.cancelMessage(conversationId: 'conv-3');
    service.onSend = null;
  });

  group('PendingMessageService', () {
    test('starts with no pending message', () {
      expect(service.hasPending, isFalse);
      expect(service.hasPendingFor('conv-1'), isFalse);
      expect(service.pendingFor('conv-1'), isNull);
    });

    test('queueMessage creates a pending message for a conversation', () {
      fakeAsync((async) {
        service.queueMessage(
          conversationId: 'conv-1',
          body: 'Hello world',
        );

        expect(service.hasPending, isTrue);
        expect(service.hasPendingFor('conv-1'), isTrue);
        expect(service.hasPendingFor('conv-2'), isFalse);
        final p = service.pendingFor('conv-1')!;
        expect(p.conversationId, 'conv-1');
        expect(p.body, 'Hello world');
        expect(p.remainingSeconds, 120);
        expect(p.replyToId, isNull);
      });
    });

    test('queueMessage with replyToId', () {
      fakeAsync((async) {
        service.queueMessage(
          conversationId: 'conv-1',
          body: 'Reply text',
          replyToId: 'msg-123',
        );

        expect(service.pendingFor('conv-1')!.replyToId, 'msg-123');
      });
    });

    test('editMessage updates the body for a conversation', () {
      fakeAsync((async) {
        service.queueMessage(conversationId: 'conv-1', body: 'Original');
        service.editMessage('Edited', conversationId: 'conv-1');

        expect(service.pendingFor('conv-1')!.body, 'Edited');
      });
    });

    test('editMessage does nothing when no pending', () {
      service.editMessage('Should not crash', conversationId: 'conv-1');
      expect(service.hasPending, isFalse);
    });

    test('cancelMessage clears the pending message for a conversation', () {
      fakeAsync((async) {
        service.queueMessage(conversationId: 'conv-1', body: 'Hello');
        expect(service.hasPendingFor('conv-1'), isTrue);

        service.cancelMessage(conversationId: 'conv-1');
        expect(service.hasPendingFor('conv-1'), isFalse);
        expect(service.hasPending, isFalse);
      });
    });

    test('sendNow dispatches immediately and clears pending', () {
      fakeAsync((async) {
        String? sentConvId;
        String? sentBody;
        String? sentReplyToId;

        service.onSend = (conversationId, body, replyToId) {
          sentConvId = conversationId;
          sentBody = body;
          sentReplyToId = replyToId;
        };

        service.queueMessage(
          conversationId: 'conv-1',
          body: 'Immediate send',
          replyToId: 'reply-1',
        );

        service.sendNow(conversationId: 'conv-1');

        expect(service.hasPendingFor('conv-1'), isFalse);
        expect(sentConvId, 'conv-1');
        expect(sentBody, 'Immediate send');
        expect(sentReplyToId, 'reply-1');
      });
    });

    test('sendNow does nothing when no pending for that conversation', () {
      bool called = false;
      service.onSend = (_, __, ___) {
        called = true;
      };

      service.sendNow(conversationId: 'conv-1');
      expect(called, isFalse);
    });

    test('timer counts down each second', () {
      fakeAsync((async) {
        service.queueMessage(conversationId: 'conv-1', body: 'Test');
        expect(service.pendingFor('conv-1')!.remainingSeconds, 120);

        async.elapse(const Duration(seconds: 5));
        expect(service.pendingFor('conv-1')!.remainingSeconds, 115);

        async.elapse(const Duration(seconds: 10));
        expect(service.pendingFor('conv-1')!.remainingSeconds, 105);
      });
    });

    test('timer auto-dispatches at 0 seconds', () {
      fakeAsync((async) {
        String? sentBody;
        service.onSend = (_, body, __) {
          sentBody = body;
        };

        service.queueMessage(conversationId: 'conv-1', body: 'Auto send');
        async.elapse(const Duration(seconds: 120));

        expect(service.hasPendingFor('conv-1'), isFalse);
        expect(sentBody, 'Auto send');
      });
    });

    test('cancelMessage stops the timer — onSend never fires', () {
      fakeAsync((async) {
        bool called = false;
        service.onSend = (_, __, ___) {
          called = true;
        };

        service.queueMessage(conversationId: 'conv-1', body: 'Cancelled');
        async.elapse(const Duration(seconds: 10));
        service.cancelMessage(conversationId: 'conv-1');
        async.elapse(const Duration(seconds: 200));

        expect(called, isFalse);
        expect(service.hasPending, isFalse);
      });
    });

    // === CONVERSATION INDEPENDENCE TESTS ===

    test('two conversations can have independent pending messages', () {
      fakeAsync((async) {
        service.queueMessage(conversationId: 'conv-1', body: 'Message A');
        service.queueMessage(conversationId: 'conv-2', body: 'Message B');

        expect(service.hasPendingFor('conv-1'), isTrue);
        expect(service.hasPendingFor('conv-2'), isTrue);
        expect(service.pendingFor('conv-1')!.body, 'Message A');
        expect(service.pendingFor('conv-2')!.body, 'Message B');
      });
    });

    test('cancelling one conversation does not affect another', () {
      fakeAsync((async) {
        service.queueMessage(conversationId: 'conv-1', body: 'Message A');
        service.queueMessage(conversationId: 'conv-2', body: 'Message B');

        service.cancelMessage(conversationId: 'conv-1');

        expect(service.hasPendingFor('conv-1'), isFalse);
        expect(service.hasPendingFor('conv-2'), isTrue);
        expect(service.pendingFor('conv-2')!.body, 'Message B');
      });
    });

    test('sendNow on one conversation does not affect another', () {
      fakeAsync((async) {
        final sent = <String>[];
        service.onSend = (convId, body, _) {
          sent.add('$convId:$body');
        };

        service.queueMessage(conversationId: 'conv-1', body: 'A');
        service.queueMessage(conversationId: 'conv-2', body: 'B');

        service.sendNow(conversationId: 'conv-1');

        expect(sent, ['conv-1:A']);
        expect(service.hasPendingFor('conv-1'), isFalse);
        expect(service.hasPendingFor('conv-2'), isTrue);
      });
    });

    test('timers run independently per conversation', () {
      fakeAsync((async) {
        service.queueMessage(conversationId: 'conv-1', body: 'A');
        async.elapse(const Duration(seconds: 30));

        service.queueMessage(conversationId: 'conv-2', body: 'B');
        async.elapse(const Duration(seconds: 30));

        // conv-1: 120 - 60 = 60 remaining
        // conv-2: 120 - 30 = 90 remaining
        expect(service.pendingFor('conv-1')!.remainingSeconds, 60);
        expect(service.pendingFor('conv-2')!.remainingSeconds, 90);
      });
    });

    test('each conversation auto-dispatches independently', () {
      fakeAsync((async) {
        final sent = <String>[];
        service.onSend = (convId, body, _) {
          sent.add('$convId:$body');
        };

        service.queueMessage(conversationId: 'conv-1', body: 'A');
        async.elapse(const Duration(seconds: 60));
        service.queueMessage(conversationId: 'conv-2', body: 'B');

        // conv-1 has 60s left, conv-2 has 120s
        async.elapse(const Duration(seconds: 60));
        // conv-1 should have auto-dispatched
        expect(sent, ['conv-1:A']);
        expect(service.hasPendingFor('conv-1'), isFalse);
        expect(service.hasPendingFor('conv-2'), isTrue);

        async.elapse(const Duration(seconds: 60));
        // conv-2 should have auto-dispatched
        expect(sent, ['conv-1:A', 'conv-2:B']);
        expect(service.hasPending, isFalse);
      });
    });

    test('editing one conversation does not affect another', () {
      fakeAsync((async) {
        service.queueMessage(conversationId: 'conv-1', body: 'Original A');
        service.queueMessage(conversationId: 'conv-2', body: 'Original B');

        service.editMessage('Edited A', conversationId: 'conv-1');

        expect(service.pendingFor('conv-1')!.body, 'Edited A');
        expect(service.pendingFor('conv-2')!.body, 'Original B');
      });
    });

    test('notifies listeners on queue, edit, cancel, sendNow', () {
      fakeAsync((async) {
        int notifyCount = 0;
        void listener() => notifyCount++;
        service.addListener(listener);

        service.queueMessage(conversationId: 'conv-1', body: 'Test');
        expect(notifyCount, 1);

        service.editMessage('New body', conversationId: 'conv-1');
        expect(notifyCount, 2);

        service.cancelMessage(conversationId: 'conv-1');
        expect(notifyCount, 3);

        service.queueMessage(conversationId: 'conv-1', body: 'Test2');
        notifyCount = 0;
        service.onSend = (_, __, ___) {};
        service.sendNow(conversationId: 'conv-1');
        expect(notifyCount, 1);

        service.removeListener(listener);
      });
    });

    test('notifies listeners on each timer tick', () {
      fakeAsync((async) {
        int notifyCount = 0;
        void listener() => notifyCount++;
        service.addListener(listener);

        service.queueMessage(conversationId: 'conv-1', body: 'Test');
        notifyCount = 0;

        async.elapse(const Duration(seconds: 3));
        expect(notifyCount, 3);

        service.removeListener(listener);
        service.cancelMessage(conversationId: 'conv-1');
      });
    });
  });
}
