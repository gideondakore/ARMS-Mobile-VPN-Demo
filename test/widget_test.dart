import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_app/main.dart';

void main() {
  testWidgets('VpnApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const VpnApp());
    expect(find.byType(VpnApp), findsOneWidget);
  });
}
