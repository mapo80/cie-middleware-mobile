import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cie_sign_flutter_platform_interface.dart';
import 'src/nfc_session_event.dart';
import 'src/pdf_signature_appearance.dart';
import 'src/pdf_signature_field_info.dart';

class MethodChannelCieSignFlutter extends CieSignFlutterPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('cie_sign_flutter');
  @visibleForTesting
  final EventChannel eventChannel = const EventChannel(
    'cie_sign_flutter/nfc_events',
  );

  Stream<NfcSessionEvent>? _eventStream;

  @override
  Future<Uint8List> mockSignPdf(
    Uint8List pdfBytes, {
    String? outputPath,
    PdfSignatureAppearance? appearance,
  }) async {
    final Uint8List? response = await methodChannel
        .invokeMethod<Uint8List>('mockSignPdf', <String, dynamic>{
          'pdf': pdfBytes,
          if (outputPath != null) 'outputPath': outputPath,
          if (appearance != null) 'appearance': appearance.toMap(),
        });
    if (response == null) {
      throw StateError('mockSignPdf returned null');
    }
    return response;
  }

  @override
  Future<Uint8List> signPdfWithNfc(
    Uint8List pdfBytes, {
    required String pin,
    PdfSignatureAppearance appearance = const PdfSignatureAppearance(),
    String? outputPath,
  }) async {
    final Uint8List? response = await methodChannel
        .invokeMethod<Uint8List>('signPdfWithNfc', <String, dynamic>{
          'pdf': pdfBytes,
          'pin': pin,
          'appearance': appearance.toMap(),
          if (outputPath != null) 'outputPath': outputPath,
        });
    if (response == null) {
      throw StateError('signPdfWithNfc returned null');
    }
    return response;
  }

  @override
  Future<bool> verifyPinWithNfc({required String pin}) async {
    final bool? verified = await methodChannel.invokeMethod<bool>(
      'verifyPinWithNfc',
      <String, dynamic>{
        'pin': pin,
      },
    );
    return verified ?? false;
  }

  @override
  Future<bool> cancelNfcSigning() async {
    final bool? canceled = await methodChannel.invokeMethod<bool>(
      'cancelNfcSigning',
    );
    return canceled ?? false;
  }

  @override
  Stream<NfcSessionEvent> watchNfcEvents() {
    _eventStream ??= eventChannel
        .receiveBroadcastStream()
        .map(
          (dynamic event) =>
              NfcSessionEvent.fromMap(Map<dynamic, dynamic>.from(event as Map)),
        )
        .asBroadcastStream();
    return _eventStream!;
  }

  /// Run PoDoFo iOS test suite (iOS only, for debugging)
  Future<Map<String, dynamic>> testPodofo(Uint8List pdfBytes) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'testPodofo',
      <String, dynamic>{'pdf': pdfBytes},
    );
    if (result == null) {
      return {'success': false, 'message': 'testPodofo returned null'};
    }
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<List<PdfSignatureFieldInfo>> extractSignatureFields(
      Uint8List pdfBytes) async {
    final List<dynamic>? response = await methodChannel.invokeMethod<List>(
      'extractSignatureFields',
      <String, dynamic>{'pdf': pdfBytes},
    );
    if (response == null) {
      return [];
    }
    return response
        .whereType<Map>()
        .map((m) => PdfSignatureFieldInfo.fromMap(Map<dynamic, dynamic>.from(m)))
        .toList();
  }
}
