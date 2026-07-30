import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_futures_predictor/services/prediction_service.dart';
import 'package:crypto_futures_predictor/models/price_data.dart';

void main() {
  group('PredictionService.calculateAnchoredVwap', () {
    late PredictionService service;

    setUp(() {
      service = PredictionService();
    });

    List<PriceData> buildPrices({
      required int count,
      required double startPrice,
      required double step,
    }) {
      final prices = <PriceData>[];
      for (var i = 0; i < count; i++) {
        final close = startPrice + step * i;
        final high = close * 1.02;
        final low = close * 0.98;
        prices.add(PriceData(
          timestamp: DateTime(2024, 1, 1, i),
          open: close - step / 2,
          high: high,
          low: low,
          close: close,
          volume: 1000.0,
        ));
      }
      return prices;
    }

    test('returns null when not enough prices', () {
      final prices = buildPrices(count: 10, startPrice: 100.0, step: 1.0);
      final vwap = service.calculateAnchoredVwap(prices, lookback: 20);
      expect(vwap, isNull);
    });

    test('returns correct VWAP for sufficient data', () {
      final prices = buildPrices(count: 25, startPrice: 100.0, step: 1.0);
      final vwap = service.calculateAnchoredVwap(prices, lookback: 20);
      expect(vwap, isNotNull);
      expect(vwap, greaterThan(0));
      final expectedVwap = (prices.sublist(5).map((p) => ((p.high + p.low + p.close) / 3) * p.volume).reduce((a, b) => a + b)) /
          (prices.sublist(5).map((p) => p.volume).reduce((a, b) => a + b));
      expect(vwap, closeTo(expectedVwap, 0.01));
    });

    test('returns null when cumulative volume is zero', () {
      final prices = <PriceData>[];
      for (var i = 0; i < 25; i++) {
        final close = 100.0 + i.toDouble();
        prices.add(PriceData(
          timestamp: DateTime(2024, 1, 1, i),
          open: close,
          high: close * 1.02,
          low: close * 0.98,
          close: close,
          volume: 0.0,
        ));
      }
      final vwap = service.calculateAnchoredVwap(prices, lookback: 20);
      expect(vwap, isNull);
    });
  });
}
