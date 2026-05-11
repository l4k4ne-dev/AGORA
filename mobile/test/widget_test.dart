// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:agora_app/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AgoraApp());

    // Verify that the app loads with the Agora title
    expect(find.text('Agora'), findsOneWidget);
  });
}
