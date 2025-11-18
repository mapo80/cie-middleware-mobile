import 'package:cie_sign_flutter/src/nfc_session_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NfcSessionEvent', () {
    test('parses known event types', () {
      final events = <NfcSessionEvent>[
        NfcSessionEvent.fromMap({'type': 'state', 'status': 'ready'}),
        NfcSessionEvent.fromMap({'type': 'listening'}),
        NfcSessionEvent.fromMap({'type': 'tag', 'tagId': 'ABCD'}),
        NfcSessionEvent.fromMap({
          'type': 'error',
          'code': 'nfc',
          'message': 'fail',
        }),
        NfcSessionEvent.fromMap({'type': 'completed', 'bytes': 1024}),
        NfcSessionEvent.fromMap({'type': 'canceled'}),
      ];

      expect(events[0].type, NfcSessionEventType.state);
      expect(events[0].status, 'ready');
      expect(events[1].type, NfcSessionEventType.listening);
      expect(events[2].type, NfcSessionEventType.tag);
      expect(events[2].extra?['tagId'], 'ABCD');
      expect(events[3].type, NfcSessionEventType.error);
      expect(events[3].message, 'fail');
      expect(events[4].type, NfcSessionEventType.completed);
      expect(events[5].type, NfcSessionEventType.canceled);
    });

    test('defaults to state event for unknown types', () {
      final event = NfcSessionEvent.fromMap({
        'type': 'mystery',
        'status': 'foo',
      });
      expect(event.type, NfcSessionEventType.state);
      expect(event.status, 'foo');
    });

    test('handles missing fields gracefully', () {
      final event = NfcSessionEvent.fromMap({});
      expect(event.type, NfcSessionEventType.state);
      expect(event.status, isNull);
      expect(event.extra, isNotNull);
    });
  });
}
