enum NfcSessionEventType { state, listening, tag, error, completed, canceled }

class NfcSessionEvent {
  const NfcSessionEvent._(
    this.type, {
    this.status,
    this.message,
    this.code,
    this.extra,
  });

  factory NfcSessionEvent.fromMap(Map<dynamic, dynamic> map) {
    final typeValue = map['type'] as String? ?? 'unknown';
    final type = _parseType(typeValue);
    final status = map['status'] as String?;
    final message = map['message'] as String?;
    final code = map['code'] as String?;
    final extra = Map<String, dynamic>.from(map);
    return NfcSessionEvent._(
      type,
      status: status,
      message: message,
      code: code,
      extra: extra,
    );
  }

  static NfcSessionEventType _parseType(String raw) {
    switch (raw) {
      case 'state':
        return NfcSessionEventType.state;
      case 'listening':
        return NfcSessionEventType.listening;
      case 'tag':
        return NfcSessionEventType.tag;
      case 'error':
        return NfcSessionEventType.error;
      case 'completed':
        return NfcSessionEventType.completed;
      case 'canceled':
        return NfcSessionEventType.canceled;
      default:
        return NfcSessionEventType.state;
    }
  }

  final NfcSessionEventType type;
  final String? status;
  final String? message;
  final String? code;
  final Map<String, dynamic>? extra;

  @override
  String toString() =>
      'NfcSessionEvent(type: $type, status: $status, code: $code, message: $message)';
}
