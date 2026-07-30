import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_futures_predictor/app.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CryptoFuturesApp());

    expect(find.text('Crypto Futures Predictor'), findsOneWidget);
  });
}