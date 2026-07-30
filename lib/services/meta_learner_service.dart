import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/prediction.dart';

class MetaLearnerParameters {
  final List<String> featureNames;
  final List<double> weights;
  final double bias;

  MetaLearnerParameters({
    required this.featureNames,
    required this.weights,
    required this.bias,
  });

  factory MetaLearnerParameters.fromJson(Map<String, dynamic> json) {
    return MetaLearnerParameters(
      featureNames: List<String>.from(json['featureNames'] as List),
      weights: (json['weights'] as List)
          .map((v) => (v as num).toDouble())
          .toList(),
      bias: (json['bias'] as num).toDouble(),
    );
  }
}

class MetaLearnerService {
  MetaLearnerParameters? _params;
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/meta_learner_params.json');
      _params = MetaLearnerParameters.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      _params = _defaultParameters();
    }
    _loaded = true;
  }

  MetaLearnerParameters _defaultParameters() {
    return MetaLearnerParameters(
      featureNames: [
        'indicatorConfidence',
        'mlProbUp',
        'mlProbDown',
        'mlProbSideways',
        'regimeProbTrending',
        'regimeProbRanging',
        'regimeProbCrisis',
      ],
      weights: [4.94, 1.86, 1.60, -2.69, 4.30, -1.91, -2.37],
      bias: -6.43,
    );
  }

  double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }

  Future<double> predictConfidence({
    required double indicatorConfidence,
    required double mlProbUp,
    required double mlProbDown,
    required double mlProbSideways,
    required Map<MarketRegime, double>? regimeProbs,
  }) async {
    await _ensureLoaded();
    final params = _params!;

    final features = [
      indicatorConfidence / 100.0,
      mlProbUp / 100.0,
      mlProbDown / 100.0,
      mlProbSideways / 100.0,
      regimeProbs?[MarketRegime.trending] ?? 0.0,
      regimeProbs?[MarketRegime.ranging] ?? 0.0,
      regimeProbs?[MarketRegime.crisis] ?? 0.0,
    ];

    double linearOutput = params.bias;
    for (var i = 0; i < features.length; i++) {
      linearOutput += params.weights[i] * features[i];
    }

    final probability = _sigmoid(linearOutput);
    return (probability * 100.0).clamp(0.0, 100.0);
  }
}
