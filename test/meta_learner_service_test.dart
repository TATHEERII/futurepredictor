import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_futures_predictor/services/meta_learner_service.dart';
import 'package:crypto_futures_predictor/models/prediction.dart';

void main() {
  group('MetaLearnerService', () {
    late MetaLearnerService service;

    setUp(() {
      service = MetaLearnerService();
    });

    test('predictConfidence returns a value between 0 and 100', () async {
      final probs = await service.predictConfidence(
        indicatorConfidence: 70.0,
        mlProbUp: 60.0,
        mlProbDown: 40.0,
        mlProbSideways: 30.0,
        regimeProbs: {
          MarketRegime.trending: 0.6,
          MarketRegime.ranging: 0.3,
          MarketRegime.crisis: 0.1,
          MarketRegime.unknown: 0.0,
        },
      );

      expect(probs, inInclusiveRange(0.0, 100.0));
    });

    test('predictConfidence returns higher confidence when models agree', () async {
      final highAgreement = await service.predictConfidence(
        indicatorConfidence: 90.0,
        mlProbUp: 85.0,
        mlProbDown: 10.0,
        mlProbSideways: 10.0,
        regimeProbs: {
          MarketRegime.trending: 0.8,
          MarketRegime.ranging: 0.1,
          MarketRegime.crisis: 0.1,
          MarketRegime.unknown: 0.0,
        },
      );

      final lowAgreement = await service.predictConfidence(
        indicatorConfidence: 90.0,
        mlProbUp: 45.0,
        mlProbDown: 45.0,
        mlProbSideways: 45.0,
        regimeProbs: {
          MarketRegime.trending: 0.33,
          MarketRegime.ranging: 0.33,
          MarketRegime.crisis: 0.34,
          MarketRegime.unknown: 0.0,
        },
      );

      expect(highAgreement, greaterThan(lowAgreement));
    });

    test('predictConfidence handles null regimeProbs', () async {
      final probs = await service.predictConfidence(
        indicatorConfidence: 50.0,
        mlProbUp: 50.0,
        mlProbDown: 50.0,
        mlProbSideways: 50.0,
        regimeProbs: null,
      );

      expect(probs, inInclusiveRange(0.0, 100.0));
    });

    test('predictConfidence uses default parameters when asset missing', () async {
      final service2 = MetaLearnerService();
      final probs = await service2.predictConfidence(
        indicatorConfidence: 80.0,
        mlProbUp: 70.0,
        mlProbDown: 30.0,
        mlProbSideways: 20.0,
        regimeProbs: {
          MarketRegime.trending: 0.5,
          MarketRegime.ranging: 0.3,
          MarketRegime.crisis: 0.2,
          MarketRegime.unknown: 0.0,
        },
      );

      expect(probs, inInclusiveRange(0.0, 100.0));
    });
  });
}
