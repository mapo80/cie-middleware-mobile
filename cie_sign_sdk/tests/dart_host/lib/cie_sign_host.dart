import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

class CieSignHostBridge {
  CieSignHostBridge._(this._library);

  factory CieSignHostBridge.open({String? libraryPath}) {
    final resolvedPath = libraryPath ?? _defaultLibraryPath();
    final lib = ffi.DynamicLibrary.open(resolvedPath);
    return CieSignHostBridge._(lib);
  }

  final ffi.DynamicLibrary _library;

  late final _mockSign = _library.lookupFunction<_MockSignNative, _MockSignDart>(
    'cie_mock_sign_pdf',
  );

  late final _mockFree = _library.lookupFunction<_MockFreeNative, _MockFreeDart>(
    'cie_mock_free',
  );

  Uint8List mockSignPdf({
    required Uint8List pdfBytes,
    required Uint8List signatureImage,
    List<String> fieldIds = const ['SignatureField1'],
    CieMockPdfOptions? options,
  }) {
    final pdfPointer = calloc<ffi.Uint8>(pdfBytes.length);
    final sigPointer = calloc<ffi.Uint8>(signatureImage.length);
    final resultStruct = calloc<_CieMockPdfResult>();
    final optsPointer = options != null ? calloc<_CieMockPdfOptions>() : ffi.nullptr;
    ffi.Pointer<ffi.Pointer<ffi.Int8>> fieldIdsPtr = ffi.nullptr;

    try {
      pdfPointer.asTypedList(pdfBytes.length).setAll(0, pdfBytes);
      sigPointer.asTypedList(signatureImage.length).setAll(0, signatureImage);

      if (options != null && optsPointer != ffi.nullptr) {
        optsPointer.ref
          ..pageIndex = options.pageIndex
          ..left = options.left
          ..bottom = options.bottom
          ..width = options.width
          ..height = options.height;
      }

      if (fieldIds.isNotEmpty) {
        fieldIdsPtr = calloc<ffi.Pointer<ffi.Int8>>(fieldIds.length);
        for (var i = 0; i < fieldIds.length; i++) {
          fieldIdsPtr.elementAt(i).value = fieldIds[i].toNativeUtf8().cast();
        }
      }

      final status = _mockSign(
        pdfPointer,
        pdfBytes.length,
        sigPointer,
        signatureImage.length,
        optsPointer,
        fieldIdsPtr,
        fieldIds.length,
        resultStruct,
      );
      if (status != 0) {
        throw StateError('cie_mock_sign_pdf failed with status $status');
      }
      final length = resultStruct.ref.length;
      final pointer = resultStruct.ref.data;
      final signed = pointer.asTypedList(length);
      final output = Uint8List(length);
      output.setAll(0, signed);
      _mockFree(pointer.cast());
      return output;
    } finally {
      calloc.free(pdfPointer);
      calloc.free(sigPointer);
      if (optsPointer != ffi.nullptr) {
        calloc.free(optsPointer);
      }
      if (fieldIdsPtr != ffi.nullptr) {
        for (var i = 0; i < fieldIds.length; i++) {
          calloc.free(fieldIdsPtr.elementAt(i).value);
        }
        calloc.free(fieldIdsPtr);
      }
      calloc.free(resultStruct);
    }
  }

  static String _defaultLibraryPath() {
    final current = Directory.current.absolute.path;
    final candidates = [
      Platform.environment['CIE_SIGN_HOST_DYLIB'],
      p.join(current, '../../build/host/libcie_sign_host_bridge.dylib'),
      p.join(current, '../build/host/libcie_sign_host_bridge.dylib'),
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final file = File(candidate);
      if (file.existsSync()) {
        return file.path;
      }
    }
    throw StateError('Unable to locate libcie_sign_host_bridge.dylib');
  }
}

class CieMockPdfOptions {
  const CieMockPdfOptions({
    this.pageIndex = 0,
    this.left = 0.1,
    this.bottom = 0.1,
    this.width = 0.4,
    this.height = 0.12,
  });

  final int pageIndex;
  final double left;
  final double bottom;
  final double width;
  final double height;
}

final class _CieMockPdfOptions extends ffi.Struct {
  @ffi.Uint32()
  external int pageIndex;

  @ffi.Float()
  external double left;

  @ffi.Float()
  external double bottom;

  @ffi.Float()
  external double width;

  @ffi.Float()
  external double height;
}

final class _CieMockPdfResult extends ffi.Struct {
  external ffi.Pointer<ffi.Uint8> data;

  @ffi.Uint64()
  external int length;
}

typedef _MockSignNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Uint8>,
  ffi.IntPtr,
  ffi.Pointer<ffi.Uint8>,
  ffi.IntPtr,
  ffi.Pointer<_CieMockPdfOptions>,
  ffi.Pointer<ffi.Pointer<ffi.Int8>>,
  ffi.IntPtr,
  ffi.Pointer<_CieMockPdfResult>,
);

typedef _MockSignDart = int Function(
  ffi.Pointer<ffi.Uint8>,
  int,
  ffi.Pointer<ffi.Uint8>,
  int,
  ffi.Pointer<_CieMockPdfOptions>,
  ffi.Pointer<ffi.Pointer<ffi.Int8>>,
  int,
  ffi.Pointer<_CieMockPdfResult>,
);

typedef _MockFreeNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _MockFreeDart = void Function(ffi.Pointer<ffi.Void>);
