import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/ml_model_info.dart';
import '../models/price_data.dart';
import '../utils/constants.dart';

class MlModelNode {
  final String type;
  final double? value;
  final int? feature;
  final double? threshold;
  final int? left;
  final int? right;

  MlModelNode({
    required this.type,
    this.value,
    this.feature,
    this.threshold,
    this.left,
    this.right,
  });

  factory MlModelNode.fromJson(Map<String, dynamic> json) {
    return MlModelNode(
      type: json['type'] as String,
      value: json['value'] != null ? (json['value'] as num).toDouble() : null,
      feature: json['feature'] as int?,
      threshold: json['threshold'] != null ? (json['threshold'] as num).toDouble() : null,
      left: json['left'] as int?,
      right: json['right'] as int?,
    );
  }
}

class MlModelTree {
  final List<MlModelNode> nodes;

  MlModelTree({required this.nodes});

  factory MlModelTree.fromJson(List<dynamic> json) {
    return MlModelTree(
      nodes: json.map((n) => MlModelNode.fromJson(n as Map<String, dynamic>)).toList(),
    );
  }

  double evaluate(List<double> features) {
    return _evalNode(0, features);
  }

  double _evalNode(int idx, List<double> features) {
    if (idx < 0 || idx >= nodes.length) return 0.5;
    final node = nodes[idx];
    if (node.type == 'leaf') {
      return node.value ?? 0.5;
    }
    final featVal = node.feature != null && node.feature! < features.length
        ? features[node.feature!]
        : 0.0;
    final goLeft = node.threshold != null && featVal <= node.threshold!;
    final childIdx = goLeft ? node.left : node.right;
    if (childIdx == null) return 0.5;
    return _evalNode(childIdx, features);
  }
}

class MlModelService {
  MlModelInfo? _modelInfo;
  List<MlModelTree> _trees = [];
  bool _loaded = false;
  bool _useFallback = false;

  bool get isModelLoaded => _loaded && !_useFallback;
  MlModelInfo? get modelInfo => _modelInfo;

  Future<void> loadModel() async {
    try {
      await _loadFromAssets();
    } catch (_) {
      _useFallback = true;
    }
  }

  Future<void> _loadFromAssets() async {
    try {
      final raw = await rootBundle.loadString('assets/ml_model.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      _parseModel(data);
    } catch (_) {
      _useFallback = true;
    }
  }

  void _parseModel(Map<String, dynamic> data) {
    _modelInfo = MlModelInfo(
      version: data['version'] as String? ?? '1.0.0',
      type: MlModelType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MlModelType.ruleBased,
      ),
      trainedAt: DateTime.tryParse(data['trainedAt'] as String? ?? '') ?? DateTime.now(),
      metrics: Map<String, double>.from(
          data['metrics'] as Map<String, dynamic>? ?? {}),
      featureNames: List<String>.from(data['featureNames'] as List? ?? []),
      treeCount: data['treeCount'] as int? ?? 0,
      baseScore: (data['baseScore'] as num?)?.toDouble() ?? 0.5,
    );

    final treesRaw = data['trees'] as List?;
    if (treesRaw != null) {
      _trees = treesRaw
          .map((t) => MlModelTree.fromJson(t as List<dynamic>))
          .toList();
    }
    _loaded = true;
  }

  List<double> extractFeatures(List<PriceData> prices) {
    if (prices.length < AppConstants.ema200Period + 10) {
      return List.filled(AppConstants.mlFeatureCount, 0.0);
    }

    final svc = _FeatureCalculator(prices);
    return [
      svc.emaAlignment(),
      svc.emaShortCross(),
      svc.emaLongCross(),
      svc.rsi(),
      svc.macdHistogram(),
      svc.macdSlope(),
      svc.adx(),
      svc.adxDirection(),
      svc.volatilityRatio(),
      svc.bollingerPosition(),
      svc.obvRising() ? 1.0 : 0.0,
      svc.cmf(),
      svc.higherHigh() ? 1.0 : 0.0,
      svc.lowerLow() ? 1.0 : 0.0,
      svc.volumeSpike() ? 1.0 : 0.0,
      svc.vroc(),
      svc.vwapRatio(),
      svc.trendScore(),
      svc.regimeProbTrending(),
      svc.regimeProbRanging(),
      svc.regimeProbCrisis(),
      svc.supportDistance(),
      svc.resistanceDistance(),
      svc.fibProximity(),
      svc.orderBlockBullish() ? 1.0 : 0.0,
      svc.orderBlockBearish() ? 1.0 : 0.0,
      svc.atr(),
      svc.priceChange(),
      svc.momentum(),
      svc.stochasticK(),
      svc.williamsR(),
      svc.cci(),
    ];
  }

  ({double up, double down, double sideways}) predict(
    List<PriceData> prices,
  ) {
    if (!_loaded || _useFallback || _trees.isEmpty || prices.isEmpty) {
      return _ruleBasedFallback(prices);
    }

    final features = extractFeatures(prices);
    if (features.isEmpty) return _ruleBasedFallback(prices);

    final treeOutputs = _trees.map((tree) => tree.evaluate(features)).toList();

    if (treeOutputs.isEmpty) return _ruleBasedFallback(prices);

    final avgOutput = treeOutputs.reduce((a, b) => a + b) / treeOutputs.length;
    final rawUp = avgOutput;
    final rawDown = 1.0 - avgOutput;
    final rawSideways = 0.0;

    final total = rawUp + rawDown + rawSideways;
    if (total <= 0) return _ruleBasedFallback(prices);

    final up = (rawUp / total * 100).clamp(0.0, 100.0);
    final down = (rawDown / total * 100).clamp(0.0, 100.0);
    final sideways = (rawSideways / total * 100).clamp(0.0, 100.0);

    return (up: up, down: down, sideways: sideways);
  }

  ({double up, double down, double sideways}) _ruleBasedFallback(
    List<PriceData> prices,
  ) {
    if (prices.length < AppConstants.ema20Period + 1) {
      return (up: 33.33, down: 33.33, sideways: 33.34);
    }

    final ema20 = _calcEma(prices, AppConstants.ema20Period);
    final ema50 = _calcEma(prices, AppConstants.ema50Period);
    final ema200 = _calcEma(prices, AppConstants.ema200Period);

    double buyScore = 0;
    double sellScore = 0;

    if (ema20 > ema50) buyScore += 1.0;
    if (ema50 > ema200) buyScore += 1.0;
    if (ema20 <= ema50) sellScore += 1.0;
    if (ema50 <= ema200) sellScore += 1.0;

    final total = buyScore + sellScore;
    if (total <= 0) return (up: 33.33, down: 33.33, sideways: 33.34);

    return (
      up: (buyScore / total * 100).clamp(0, 100),
      down: (sellScore / total * 100).clamp(0, 100),
      sideways: 0.0,
    );
  }

  double _calcEma(List<PriceData> prices, int period) {
    if (prices.isEmpty) return 0;
    if (prices.length < period) {
      return prices.fold<double>(0, (s, p) => s + p.close) / prices.length;
    }
    final multiplier = 2.0 / (period + 1);
    double ema = prices.sublist(0, period)
        .fold<double>(0, (s, p) => s + p.close) / period;
    for (var i = period; i < prices.length; i++) {
      ema = (prices[i].close - ema) * multiplier + ema;
    }
    return ema;
  }
}

class _FeatureCalculator {
  final List<PriceData> prices;
  _FeatureCalculator(this.prices);

  double _ema(int period) {
    if (prices.isEmpty) return 0;
    if (prices.length < period) {
      return prices.fold<double>(0, (s, p) => s + p.close) / prices.length;
    }
    final mult = 2.0 / (period + 1);
    double e = prices.sublist(0, period).fold<double>(0, (s, p) => s + p.close) / period;
    for (var i = period; i < prices.length; i++) {
      e = (prices[i].close - e) * mult + e;
    }
    return e;
  }

  double _sma(int period) {
    if (prices.length < period) return 0;
    return prices.sublist(prices.length - period)
        .fold<double>(0, (s, p) => s + p.close) / period;
  }

  double _atr() {
    final period = AppConstants.atrPeriod;
    if (prices.length < period + 1) return 0;
    final trList = <double>[];
    for (var i = 1; i < prices.length; i++) {
      final h = prices[i].high - prices[i].low;
      final hc = (prices[i].high - prices[i - 1].close).abs();
      final lc = (prices[i].low - prices[i - 1].close).abs();
      trList.add([h, hc, lc].reduce((a, b) => a > b ? a : b));
    }
    if (trList.length < period) return 0;
    var atr = trList.sublist(0, period).fold<double>(0, (s, t) => s + t) / period;
    for (var i = period; i < trList.length; i++) {
      atr = (atr * (period - 1) + trList[i]) / period;
    }
    return atr;
  }

  double _macdLine() {
    return _ema(AppConstants.macdFastPeriod) - _ema(AppConstants.macdSlowPeriod);
  }

  double _macdSignal() {
    final macdValues = <double>[];
    for (var i = AppConstants.macdSlowPeriod; i <= prices.length; i++) {
      macdValues.add(_macdLineForSlice(prices.sublist(0, i)));
    }
    if (macdValues.length < AppConstants.macdSignalPeriod) {
      return macdValues.isNotEmpty ? macdValues.last : 0;
    }
    return macdValues.sublist(macdValues.length - AppConstants.macdSignalPeriod)
        .fold<double>(0, (s, v) => s + v) / AppConstants.macdSignalPeriod;
  }

  double _macdLineForSlice(List<PriceData> slice) {
    if (slice.length < AppConstants.macdSlowPeriod) return 0;
    final fast = _emaForSlice(slice, AppConstants.macdFastPeriod);
    final slow = _emaForSlice(slice, AppConstants.macdSlowPeriod);
    return fast - slow;
  }

  double _emaForSlice(List<PriceData> slice, int period) {
    if (slice.length < period) {
      return slice.fold<double>(0, (s, p) => s + p.close) / slice.length;
    }
    final mult = 2.0 / (period + 1);
    double e = slice.sublist(0, period).fold<double>(0, (s, p) => s + p.close) / period;
    for (var i = period; i < slice.length; i++) {
      e = (slice[i].close - e) * mult + e;
    }
    return e;
  }

  double _rsi({int period = 14}) {
    if (prices.length < period + 1) return 50;
    final gains = <double>[];
    final losses = <double>[];
    for (var i = prices.length - period; i < prices.length; i++) {
      final diff = prices[i].close - prices[i - 1].close;
      if (diff > 0) { gains.add(diff); losses.add(0); }
      else { gains.add(0); losses.add(diff.abs()); }
    }
    final avgGain = gains.fold<double>(0, (s, g) => s + g) / period;
    final avgLoss = losses.fold<double>(0, (s, l) => s + l) / period;
    if (avgLoss == 0) return 100;
    return 100 - (100 / (1 + (avgGain / avgLoss)));
  }

  double _adx() {
    final period = AppConstants.adxPeriod;
    if (prices.length < period + 1) return 0;
    final plusDms = <double>[];
    final minusDms = <double>[];
    final trList = <double>[];
    for (var i = 1; i < prices.length; i++) {
      final up = prices[i].high - prices[i - 1].high;
      final down = prices[i - 1].low - prices[i].low;
      final hl = prices[i].high - prices[i].low;
      final hc = (prices[i].high - prices[i - 1].close).abs();
      final lc = (prices[i].low - prices[i - 1].close).abs();
      trList.add([hl, hc, lc].reduce((a, b) => a > b ? a : b));
      plusDms.add(up > down && up > 0 ? up : 0);
      minusDms.add(down > up && down > 0 ? down : 0);
    }
    if (trList.length < period) return 0;
    double sp = plusDms.sublist(0, period).fold<double>(0, (s, v) => s + v);
    double sm = minusDms.sublist(0, period).fold<double>(0, (s, v) => s + v);
    double st = trList.sublist(0, period).fold<double>(0, (s, t) => s + t);
    final dxs = <double>[];
    for (var i = period; i < trList.length; i++) {
      sp = sp - (sp / period) + plusDms[i];
      sm = sm - (sm / period) + minusDms[i];
      st = st - (st / period) + trList[i];
      final pd = sp / st * 100;
      final md = sm / st * 100;
      dxs.add((pd - md).abs() / (pd + md) * 100);
    }
    if (dxs.isEmpty) return 0;
    if (dxs.length < AppConstants.adxSmoothing) {
      return dxs.fold<double>(0, (s, v) => s + v) / dxs.length;
    }
    var adx = dxs.sublist(0, AppConstants.adxSmoothing).fold<double>(0, (s, v) => s + v) / AppConstants.adxSmoothing;
    for (var i = AppConstants.adxSmoothing; i < dxs.length; i++) {
      adx = (adx * (AppConstants.adxSmoothing - 1) + dxs[i]) / AppConstants.adxSmoothing;
    }
    return adx;
  }

  double _plusDi() {
    final period = AppConstants.adxPeriod;
    if (prices.length < period + 1) return 0;
    final plusDms = <double>[];
    final minusDms = <double>[];
    final trList = <double>[];
    for (var i = 1; i < prices.length; i++) {
      final up = prices[i].high - prices[i - 1].high;
      final down = prices[i - 1].low - prices[i].low;
      final hl = prices[i].high - prices[i].low;
      final hc = (prices[i].high - prices[i - 1].close).abs();
      final lc = (prices[i].low - prices[i - 1].close).abs();
      trList.add([hl, hc, lc].reduce((a, b) => a > b ? a : b));
      plusDms.add(up > down && up > 0 ? up : 0);
      minusDms.add(down > up && down > 0 ? down : 0);
    }
    if (trList.length < period) return 0;
    double sp = plusDms.sublist(0, period).fold<double>(0, (s, v) => s + v);
    double sm = minusDms.sublist(0, period).fold<double>(0, (s, v) => s + v);
    double st = trList.sublist(0, period).fold<double>(0, (s, t) => s + t);
    for (var i = period; i < trList.length; i++) {
      sp = sp - (sp / period) + plusDms[i];
      sm = sm - (sm / period) + minusDms[i];
      st = st - (st / period) + trList[i];
    }
    return st > 0 ? sp / st * 100 : 0;
  }

  double _minusDi() {
    final period = AppConstants.adxPeriod;
    if (prices.length < period + 1) return 0;
    final plusDms = <double>[];
    final minusDms = <double>[];
    final trList = <double>[];
    for (var i = 1; i < prices.length; i++) {
      final up = prices[i].high - prices[i - 1].high;
      final down = prices[i - 1].low - prices[i].low;
      final hl = prices[i].high - prices[i].low;
      final hc = (prices[i].high - prices[i - 1].close).abs();
      final lc = (prices[i].low - prices[i - 1].close).abs();
      trList.add([hl, hc, lc].reduce((a, b) => a > b ? a : b));
      plusDms.add(up > down && up > 0 ? up : 0);
      minusDms.add(down > up && down > 0 ? down : 0);
    }
    if (trList.length < period) return 0;
    double sp = plusDms.sublist(0, period).fold<double>(0, (s, v) => s + v);
    double sm = minusDms.sublist(0, period).fold<double>(0, (s, v) => s + v);
    double st = trList.sublist(0, period).fold<double>(0, (s, t) => s + t);
    for (var i = period; i < trList.length; i++) {
      sp = sp - (sp / period) + plusDms[i];
      sm = sm - (sm / period) + minusDms[i];
      st = st - (st / period) + trList[i];
    }
    return st > 0 ? sm / st * 100 : 0;
  }

  double _cmf() {
    final period = AppConstants.cmfPeriod;
    if (prices.length < period) return 0;
    final slice = prices.sublist(prices.length - period);
    double mfVol = 0;
    double volSum = 0;
    for (final p in slice) {
      final range = p.high - p.low;
      if (range == 0) continue;
      final mf = ((p.close - p.low) - (p.high - p.close)) / range;
      mfVol += mf * p.volume;
      volSum += p.volume;
    }
    return volSum > 0 ? mfVol / volSum : 0;
  }

  double _bollingerPosition() {
    final period = AppConstants.bollingerPeriod;
    if (prices.length < period) return 0.5;
    final sma = _sma(period);
    final slice = prices.sublist(prices.length - period);
    final variance = slice.map((p) => pow(p.close - sma, 2))
        .fold<double>(0, (s, d) => s + d) / period;
    final stdDev = sqrt(variance);
    if (stdDev == 0) return 0.5;
    return ((prices.last.close - sma) / (2 * stdDev) + 0.5).clamp(0, 1);
  }

  double volumeSma(int period) {
    if (prices.length < period) return 0;
    return prices.sublist(prices.length - period)
        .fold<double>(0, (s, p) => s + p.volume) / period;
  }

  bool _isVolumeSpike() {
    final current = prices.last.volume;
    final avg = volumeSma(AppConstants.volumeSmaPeriod);
    return avg > 0 && current > avg * AppConstants.volumeSpikeMultiplier;
  }

  bool _isObvRising(List<PriceData> prices) {
    if (prices.length < AppConstants.obvLookback + 1) return false;
    return _calcObv(prices) > _calcObv(prices.sublist(0, prices.length - AppConstants.obvLookback));
  }

  double _calcObv(List<PriceData> pts) {
    double obv = 0;
    for (var i = 1; i < pts.length; i++) {
      if (pts[i].close > pts[i - 1].close) {
        obv += pts[i].volume;
      } else if (pts[i].close < pts[i - 1].close) {
        obv -= pts[i].volume;
      }
    }
    return obv;
  }

  bool _hasBullishOrderBlock() {
    if (prices.length < 3) return false;
    for (var i = 2; i < prices.length; i++) {
      final prev = prices[i - 2];
      final curr = prices[i - 1];
      final next = prices[i];
      if (prev.close < prev.open && curr.close < curr.open &&
          next.close > next.open && next.close > prev.open) {
        return true;
      }
    }
    return false;
  }

  bool _hasBearishOrderBlock() {
    if (prices.length < 3) return false;
    for (var i = 2; i < prices.length; i++) {
      final prev = prices[i - 2];
      final curr = prices[i - 1];
      final next = prices[i];
      if (prev.close > prev.open && curr.close > curr.open &&
          next.close < next.open && next.close < prev.open) {
        return true;
      }
    }
    return false;
  }

  // Feature extraction methods used by extractFeatures
  double emaAlignment() {
    if (prices.length < AppConstants.ema200Period + 10) return 0.5;
    final e20 = _ema(AppConstants.ema20Period);
    final e50 = _ema(AppConstants.ema50Period);
    final e200 = _ema(AppConstants.ema200Period);
    if (e50 <= 0 || e200 <= 0) return 0.5;
    final short = (e20 - e50) / e50;
    final long = (e50 - e200) / e200;
    return ((short + long) / 2 + 0.1).clamp(0.0, 1.0);
  }

  double emaShortCross() {
    if (prices.length < AppConstants.ema20Period + 1) return 0.5;
    final e20 = _ema(AppConstants.ema20Period);
    final e50 = _ema(AppConstants.ema50Period);
    if (e50 == 0) return 0.5;
    return ((e20 - e50) / e50 + 0.1).clamp(0.0, 1.0);
  }

  double emaLongCross() {
    if (prices.length < AppConstants.ema50Period + 1) return 0.5;
    final e50 = _ema(AppConstants.ema50Period);
    final e200 = _ema(AppConstants.ema200Period);
    if (e200 == 0) return 0.5;
    return ((e50 - e200) / e200 + 0.1).clamp(0.0, 1.0);
  }

  double rsi() {
    return _rsi() / 100.0;
  }

  double macdHistogram() {
    final hist = _macdLine() - _macdSignal();
    return (hist / 100).clamp(0.0, 1.0);
  }

  double macdSlope() {
    if (prices.length < AppConstants.macdSlowPeriod + AppConstants.macdSignalPeriod + 10) return 0.5;
    final currHist = _macdLine() - _macdSignal();
    final olderSlice = prices.length > 6 ? prices.sublist(0, prices.length - 5) : prices;
    final olderHist = _macdLineForSlice(olderSlice) - _macdSignal();
    return ((currHist - olderHist) / 100 + 0.5).clamp(0.0, 1.0);
  }

  double adx() {
    return (_adx() / 50.0).clamp(0.0, 1.0);
  }

  double adxDirection() {
    final pd = _plusDi();
    final md = _minusDi();
    final total = pd + md;
    if (total == 0) return 0.5;
    return (pd / total).clamp(0.0, 1.0);
  }

  double volatilityRatio() {
    final atr = _atr();
    if (prices.isEmpty || atr == 0) return 0.5;
    return (atr / prices.last.close).clamp(0.0, 1.0);
  }

  double bollingerPosition() {
    return _bollingerPosition();
  }

  bool obvRising() => _isObvRising(prices);
  double cmf() => _cmf();
  bool higherHigh() {
    if (prices.length < 21) return false;
    return prices.last.high > prices.sublist(prices.length - 21, prices.length - 1)
        .map((p) => p.high).reduce((a, b) => a > b ? a : b);
  }
  bool lowerLow() {
    if (prices.length < 21) return false;
    return prices.last.low < prices.sublist(prices.length - 21, prices.length - 1)
        .map((p) => p.low).reduce((a, b) => a < b ? a : b);
  }
  bool volumeSpike() => _isVolumeSpike();
  double vroc() {
    if (prices.length < AppConstants.volumeLookbackPeriod + 1) return 0.5;
    final curr = prices.last.volume;
    final past = prices[prices.length - AppConstants.volumeLookbackPeriod - 1].volume;
    if (past == 0) return 0.5;
    return ((curr - past) / past / 100 + 0.5).clamp(0.0, 1.0);
  }
  double vwapRatio() {
    // Simplified VWAP ratio approximation
    if (prices.length < 20) return 0.5;
    final slice = prices.sublist(prices.length - 20);
    double cumTpVol = 0;
    double cumVol = 0;
    for (final p in slice) {
      final tp = (p.high + p.low + p.close) / 3;
      cumTpVol += tp * p.volume;
      cumVol += p.volume;
    }
    if (cumVol == 0 || prices.isEmpty) return 0.5;
    final vwap = cumTpVol / cumVol;
    return (prices.last.close / vwap).clamp(0.0, 2.0) / 2.0;
  }
  double trendScore() {
    return 0.5;
  }
  double regimeProbTrending() {
    return 0.5;
  }
  double regimeProbRanging() {
    return 0.5;
  }
  double regimeProbCrisis() {
    return 0.0;
  }
  double supportDistance() {
    return 0.5;
  }
  double resistanceDistance() {
    return 0.5;
  }
  double fibProximity() {
    return 0.5;
  }
  bool orderBlockBullish() => _hasBullishOrderBlock();
  bool orderBlockBearish() => _hasBearishOrderBlock();
  double atr() {
    return (_atr() / 100).clamp(0.0, 1.0);
  }
  double priceChange() {
    if (prices.length < 2) return 0.5;
    return ((prices.last.close - prices.first.open) / prices.first.open + 0.1).clamp(0.0, 1.0);
  }
  double momentum() {
    if (prices.length < 11) return 0.5;
    final atr = _atr();
    if (atr == 0) return 0.5;
    return ((prices.last.close - prices[prices.length - 11].close) / atr + 0.5).clamp(0.0, 1.0);
  }
  double stochasticK() {
    if (prices.length < 14) return 0.5;
    final recent = prices.sublist(prices.length - 14);
    final high = recent.map((p) => p.high).reduce((a, b) => a > b ? a : b);
    final low = recent.map((p) => p.low).reduce((a, b) => a < b ? a : b);
    final range = high - low;
    if (range == 0) return 0.5;
    return ((prices.last.close - low) / range).clamp(0.0, 1.0);
  }
  double williamsR() {
    if (prices.length < 14) return 0.5;
    final recent = prices.sublist(prices.length - 14);
    final high = recent.map((p) => p.high).reduce((a, b) => a > b ? a : b);
    final low = recent.map((p) => p.low).reduce((a, b) => a < b ? a : b);
    final range = high - low;
    if (range == 0) return 0.5;
    return ((high - prices.last.close) / range).clamp(0.0, 1.0);
  }
  double cci() {
    if (prices.length < 20) return 0.5;
    final period = 20;
    final slice = prices.sublist(prices.length - period);
    final tp = slice.map((p) => (p.high + p.low + p.close) / 3).toList();
    final sma = tp.fold<double>(0, (s, v) => s + v) / period;
    final mad = tp.map((v) => (v - sma).abs())
        .fold<double>(0, (s, v) => s + v) / period;
    if (mad == 0) return 0.5;
    return ((tp.last - sma) / (0.015 * mad) / 100 + 0.5).clamp(0.0, 1.0);
  }
}