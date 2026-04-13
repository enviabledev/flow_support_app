import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/pending_message_service.dart';

void main() {
  late PendingMessageService service;

  setUp(() {
    service = PendingMessageService.instance;
    service.cancelMessage();
    service.onSend = null;
  });

  group('PendingMessageService', () {
    test('starts with no pending message', () {
      expect(service.hasPending, isFalse);
      expect(service.pending, isNull);
    });

    test('queueMessage creates a pending message', () {
      fakeAsync((async) {
        service.queueMessage(
          conversationId: 'conv-1',
          body: 'Hello world',
        );

        expect(service.hasPending, isTrue);
        expect(service.pending!.conversationId, 'conv-1');
        expect(service.pending!.body, 'Hello world');
        expect(service.pending!.remainingSeconds, 120);
        expect(service.pending!.replyToId, isNull);
      });
    });

    test('queueMessage with replyToId', () {
      fakeAsync((async) {
        service.queueMessage(
          conversationId: 'conv-1',
          body: 'Reply text',
          replyToId: 'msg-123',
        );

        expect(service.pending!.replyToId, 'msg-123');
      });
    });

    test('editMessage updates the body', () {
      fakeAsync((async) {
        service.queueMessage(conversationId: 'conv-1', body: 'Original');
        service.editMessage('Edited');

        expect(service.pending!.body, 'Edited');
      });
    });

    test('editMessage does nothing when no pending', () {
      service.editMessage('Should not crash');
      expect(service.hasPending, isFalse);
    });

    test('cancelMessage clears the pending message', () {
      fakeAsync((async) {
        service.queueMessage(conversationId: 'conv-1', body: 'Hello');
        expect(service.hasPending, isTrue);

        service.cancelMessage();
        expect(service.hasPending, isFalse);
        expect(service.pending, isNull);
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

        service.sendNow();

        expect(service.hasPending, isFalse);
        expect(sentConvId, 'conv-1');
        expect(sentBody, 'Immediate send');
        expect(sentReplyToId, 'reply-1');
      });
    });

    test('sendNow does nothing when no pending', () {
      bool called = false;
      service.onSend = (_, __, ___) {
        called = true;
      };

      service.sendNow();
      expect(called, isFalse);
    });

    test('timer counts down each second', () {
      fakeAsync((async) {
        service.queueMessage(conversationId: 'conv-1', body: 'Test');
        expect(service.pending!.remainingSeconds, 120);

        async.elapse(const Duration(seconds: 5));
        expect(service.pending!.remainingSeconds, 115);

        async.elapse(const Duration(seconds: 10));
        expect(service.pending!.remainingSeconds, 105);
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

        expect(service.hasPending, isFalse);
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
        service.cancelMessage();
        async.elapse(const Duration(seconds: 200));

        expect(called, isFalse);
        expect(service.hasPending, isFalse);
      });
    });

    test('queueMessage replaces existing pending with fresh timer', () {
      fakeAsync((async) {
        service.queueMessage(conversationId: 'conv-1', body: 'First');
        async.elapse(const Duration(seconds: 60));
        expect(service.pending!.remainingSeconds, 60);

        service.queueMessage(conversationId: 'conv-2', body: 'Second');
        expect(service.pending!.body, 'Second');
        expect(service.pending!.conversationId, 'conv-2');
        expect(service.pending!.remainingSeconds, 120);
      });
    });

    test('old pending does not auto-send after being replaced', () {
      fakeAsync((async) {
        int sendCount = 0;
        service.onSend = (_, __, ___) {
          sendCount++;
        };

        service.queueMessage(conversationId: 'conv-1', body: 'First');
        async.elapse(const Duration(seconds: 60));

        service.queueMessage(conversationId: 'conv-2', body: 'Second');
        async.elapse(const Duration(seconds: 120));

        expect(sendCount, 1);
      });
    });

    test('notifies listeners on queue, edit, cancel, sendNow', () {
      fakeAsync((async) {
        int notifyCount = 0;
        void listener() => notifyCount++;
        service.addListener(listener);

        service.queueMessage(conversationId: 'conv-1', body: 'Test');
        expect(notifyCount, 1);

        service.editMessage('New body');
        expect(notifyCount, 2);

        service.cancelMessage();
        expect(notifyCount, 3);

        service.queueMessage(conversationId: 'conv-1', body: 'Test2');
        notifyCount = 0;
        service.onSend = (_, __, ___) {};
        service.sendNow();
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
        service.cancelMessage();
      });
    });
  });
}
