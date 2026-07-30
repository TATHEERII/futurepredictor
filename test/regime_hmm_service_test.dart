import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_futures_predictor/services/regime_hmm_service.dart';
import 'package:crypto_futures_predictor/models/price_data.dart';
import 'package:crypto_futures_predictor/models/prediction.dart';

void main() {
  group('RegimeHmmService', () {
    late RegimeHmmService service;

    setUp(() {
      service = RegimeHmmService();
    });

    List<PriceData> buildTrendingPrices({
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

    List<PriceData> buildRangingPrices({
      required int count,
      required double centerPrice,
      required double amplitude,
    }) {
      final prices = <PriceData>[];
      final rng = Random(42);
      for (var i = 0; i < count; i++) {
        final noise = (rng.nextDouble() - 0.5) * amplitude;
        final close = centerPrice + noise;
        final high = close * 1.01;
        final low = close * 0.99;
        prices.add(PriceData(
          timestamp: DateTime(2024, 1, 1, i),
          open: close,
          high: high,
          low: low,
          close: close,
          volume: 1000.0,
        ));
      }
      return prices;
    }

    test('computeRegimeProbabilities returns valid probabilities for uptrend', () async {
      final prices = buildTrendingPrices(count: 250, startPrice: 100.0, step: 1.0);
      final probs = await service.computeRegimeProbabilities(prices);

      expect(probs.keys, containsAll(MarketRegime.values));
      final total = probs.values.fold<double>(0, (sum, v) => sum + v);
      expect(total, closeTo(1.0, 0.01));
      expect(probs[MarketRegime.trending], greaterThan(0.0));
      expect(probs[MarketRegime.ranging], greaterThan(0.0));
    });

    test('computeRegimeProbabilities returns valid probabilities for ranging', () async {
      final prices = buildRangingPrices(count: 250, centerPrice: 100.0, amplitude: 2.0);
      final probs = await service.computeRegimeProbabilities(prices);

      expect(probs.keys, containsAll(MarketRegime.values));
      final total = probs.values.fold<double>(0, (sum, v) => sum + v);
      expect(total, closeTo(1.0, 0.01));
    });

    test('computeRegimeProbabilities returns uniform for empty prices', () async {
      final probs = await service.computeRegimeProbabilities([]);
      expect(probs[MarketRegime.trending], closeTo(0.33, 0.01));
      expect(probs[MarketRegime.ranging], closeTo(0.33, 0.01));
      expect(probs[MarketRegime.unknown], closeTo(0.34, 0.01));
    });

    test('computeRegimeProbabilities returns uniform for single price', () async {
      final prices = buildRangingPrices(count: 1, centerPrice: 100.0, amplitude: 2.0);
      final probs = await service.computeRegimeProbabilities(prices);
      expect(probs[MarketRegime.trending], closeTo(0.33, 0.01));
      expect(probs[MarketRegime.ranging], closeTo(0.33, 0.01));
    });
  });
}
