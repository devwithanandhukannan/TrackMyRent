import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack_mobile/main.dart';

void main() {
  testWidgets('RentTrack app test', (WidgetTester tester) async {
    await tester.pumpWidget(const RentTrackApp());
    expect(find.text('RentTrack Dashboard'), findsOneWidget);
  });
}
