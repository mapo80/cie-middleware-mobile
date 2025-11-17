// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:cie_sign_flutter_example/main.dart';

void main() {
  testWidgets('Initial status text is visible', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(
      enablePdfView: false,
      loadSamplePdf: () async => Uint8List.fromList('%PDF'.codeUnits),
      loadSignatureImage: () async => Uint8List.fromList([0x00, 0x01]),
    ));
    expect(find.textContaining('Premi il pulsante'), findsOneWidget);
  });
}
