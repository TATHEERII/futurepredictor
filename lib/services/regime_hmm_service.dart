import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/price_data.dart';
import '../models/prediction.dart';
import '../utils/constants.dart';

class RegimeHmmParameters {
  final List<String> states;
  final List<List<double>> means;
  final List<List<double>> variances;
  final List<List<double>> transitionMatrix;
  final List<double> initialProbabilities;

  RegimeHmmParameters({
    required this.states,
    required this.means,
    required this.variances,
    required this.transitionMatrix,
    required this.initialProbabilities,
  });

  factory RegimeHmmParameters.fromJson(Map<String, dynamic> json) {
    return RegimeHmmParameters(
      states: List<String>.from(json['states'] as List),
      means: (json['means'] as List)
          .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
          .toList(),
      variances: (json['variances'] as List)
          .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
          .toList(),
      transitionMatrix: (json['transitionMatrix'] as List)
          .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
          .toList(),
      initialProbabilities: (json['initialProbabilities'] as List)
          .map((v) => (v as num).toDouble())
          .toList(),
    );
  }
}

class RegimeHmmService {
  RegimeHmmParameters? _params;
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/hmm_regime_params.json');
      _params = RegimeHmmParameters.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      _params = _defaultParameters();
    }
    _loaded = true;
  }

  RegimeHmmParameters _defaultParameters() {
    return RegimeHmmParameters(
      states: ['uptrend', 'downtrend', 'ranging'],
      means: [
        [0.0029, 0.0150, 35.17],
        [-0.0029, 0.0150, 29.97],
        [0.0000, 0.0060, 15.00],
      ],
      variances: [
        [3.8e-05, 1.0e-05, 62.0],
        [3.8e-05, 9.6e-06, 62.1],
        [1.0e-05, 5.4e-06, 25.1],
      ],
      transitionMatrix: [
        [0.709, 0.087, 0.203],
        [0.091, 0.704, 0.205],
        [0.251, 0.259, 0.489],
      ],
      initialProbabilities: [0.260, 0.276, 0.464],
    );
  }

  List<List<double>> _extractFeatures(List<PriceData> prices) {
    final features = <List<double>>[];
    for (var i = 1; i < prices.length; i++) {
      final ret = (prices[i].close - prices[i - 1].close) / prices[i - 1].close;
      final rangeRatio = (prices[i].high - prices[i].low) / prices[i].close;
      features.add([ret, rangeRatio]);
    }
    return features;
  }

  double _gaussianPdf(double x, double mean, double variance) {
    final diff = x - mean;
    final coeff = 1.0 / sqrt(2.0 * pi * variance);
    final exponent = -0.5 * (diff * diff / variance);
    return coeff * exp(exponent);
  }

  Future<Map<MarketRegime, double>> computeRegimeProbabilities(List<PriceData> prices) async {
    await _ensureLoaded();
    final params = _params!;
    final features = _extractFeatures(prices);
    if (features.isEmpty) {
      return _uniformRegimeProbabilities();
    }

    final adx = _currentAdx(prices);
    final n = params.states.length;
    final T = features.length;

    final scaled = List.generate(T, (t) => List.filled(n, 0.0));
    final norm = List.filled(T, 0.0);

    for (var s = 0; s < n; s++) {
      final retMean = params.means[s][0];
      final retVar = max(params.variances[s][0], 1e-12);
      final rangeMean = params.means[s][1];
      final rangeVar = max(params.variances[s][1], 1e-12);
      final adxMean = params.means[s][2];
      final adxVar = max(params.variances[s][2], 1e-12);

      scaled[0][s] = params.initialProbabilities[s] *
          _gaussianPdf(features[0][0], retMean, retVar) *
          _gaussianPdf(features[0][1], rangeMean, rangeVar) *
          _gaussianPdf(adx, adxMean, adxVar);
    }

    norm[0] = scaled[0].fold<double>(0, (sum, v) => sum + v);
    if (norm[0] > 0) {
      for (var s = 0; s < n; s++) {
        scaled[0][s] /= norm[0];
      }
    }

    for (var t = 1; t < T; t++) {
      for (var s = 0; s < n; s++) {
        double sum = 0;
        for (var prev = 0; prev < n; prev++) {
          sum += scaled[t - 1][prev] * params.transitionMatrix[prev][s];
        }
        final retMean = params.means[s][0];
        final retVar = max(params.variances[s][0], 1e-12);
        final rangeMean = params.means[s][1];
        final rangeVar = max(params.variances[s][1], 1e-12);
        final adxMean = params.means[s][2];
        final adxVar = max(params.variances[s][2], 1e-12);

        scaled[t][s] = sum *
            _gaussianPdf(features[t][0], retMean, retVar) *
            _gaussianPdf(features[t][1], rangeMean, rangeVar) *
            _gaussianPdf(adx, adxMean, adxVar);
      }
      norm[t] = scaled[t].fold<double>(0, (sum, v) => sum + v);
      if (norm[t] > 0) {
        for (var s = 0; s < n; s++) {
          scaled[t][s] /= norm[t];
        }
      }
    }

    final last = scaled[T - 1];
    final total = last.fold<double>(0, (sum, v) => sum + v);
    if (total <= 0) return _uniformRegimeProbabilities();

    final uptrend = last[0] / total;
    final downtrend = last[1] / total;
    final ranging = last[2] / total;

    return {
      MarketRegime.trending: (uptrend + downtrend).clamp(0.0, 1.0),
      MarketRegime.ranging: ranging.clamp(0.0, 1.0),
      MarketRegime.crisis: 0.0,
      MarketRegime.unknown: 0.0,
    };
  }

  double _currentAdx(List<PriceData> prices) {
    if (prices.length < AppConstants.adxPeriod + 1) return 15.0;
    final period = AppConstants.adxPeriod;
    final plusDms = <double>[];
    final minusDms = <double>[];
    final trList = <double>[];

    for (var i = 1; i < prices.length; i++) {
      final upMove = prices[i].high - prices[i - 1].high;
      final downMove = prices[i - 1].low - prices[i].low;
      final highLow = prices[i].high - prices[i].low;
      final highPrevClose = (prices[i].high - prices[i - 1].close).abs();
      final lowPrevClose = (prices[i].low - prices[i - 1].close).abs();
      final tr = [highLow, highPrevClose, lowPrevClose].reduce((a, b) => a > b ? a : b);
      trList.add(tr);
      plusDms.add(upMove > downMove && upMove > 0 ? upMove : 0);
      minusDms.add(downMove > upMove && downMove > 0 ? downMove : 0);
    }

    if (trList.length < period) return 15.0;

    double smoothedPlusDm = plusDms.sublist(0, period).fold<double>(0, (sum, v) => sum + v);
    double smoothedMinusDm = minusDms.sublist(0, period).fold<double>(0, (sum, v) => sum + v);
    double smoothedTr = trList.sublist(0, period).fold<double>(0, (sum, v) => sum + v);

    final dxValues = <double>[];
    for (var i = period; i < trList.length; i++) {
      smoothedPlusDm = smoothedPlusDm - (smoothedPlusDm / period) + plusDms[i];
      smoothedMinusDm = smoothedMinusDm - (smoothedMinusDm / period) + minusDms[i];
      smoothedTr = smoothedTr - (smoothedTr / period) + trList[i];
      final plusDi = smoothedPlusDm / smoothedTr * 100;
      final minusDi = smoothedMinusDm / smoothedTr * 100;
      final diSum = plusDi + minusDi;
      final dx = diSum > 0 ? (plusDi - minusDi).abs() / diSum * 100 : 0.0;
      dxValues.add(dx);
    }

    if (dxValues.isEmpty) return 15.0;
    if (dxValues.length < AppConstants.adxSmoothing) {
      return dxValues.fold<double>(0, (sum, v) => sum + v) / dxValues.length;
    }
    var adx = dxValues.sublist(0, AppConstants.adxSmoothing).fold<double>(0, (sum, v) => sum + v) / AppConstants.adxSmoothing;
    for (var i = AppConstants.adxSmoothing; i < dxValues.length; i++) {
      adx = (adx * (AppConstants.adxSmoothing - 1) + dxValues[i]) / AppConstants.adxSmoothing;
    }
    return adx.isNaN ? 15.0 : adx;
  }

  Map<MarketRegime, double> _uniformRegimeProbabilities() {
    return {
      MarketRegime.trending: 0.33,
      MarketRegime.ranging: 0.33,
      MarketRegime.crisis: 0.0,
      MarketRegime.unknown: 0.34,
    };
  }
}
