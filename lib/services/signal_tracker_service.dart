import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prediction.dart';
import '../models/price_data.dart';
import '../utils/constants.dart';

/// A live prediction that has been recorded and is waiting to be resolved
/// once enough time/candles have passed, or has already been resolved.
class TrackedSignal {
  final String symbol;
  final SignalType signal;
  final DateTime timestamp;
  final double entryPrice;
  final double stopLoss;
  final double takeProfit;
  final double confidence;
  bool resolved;
  bool? win;
  double? resultReturnPercent;

  TrackedSignal({
    required this.symbol,
    required this.signal,
    required this.timestamp,
    required this.entryPrice,
    required this.stopLoss,
    required this.takeProfit,
    required this.confidence,
    this.resolved = false,
    this.win,
    this.resultReturnPercent,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'signal': signal.name,
        'timestamp': timestamp.toIso8601String(),
        'entryPrice': entryPrice,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'confidence': confidence,
        'resolved': resolved,
        'win': win,
        'resultReturnPercent': resultReturnPercent,
      };

  factory TrackedSignal.fromJson(Map<String, dynamic> json) => TrackedSignal(
        symbol: json['symbol'] as String,
        signal: SignalType.values.byName(json['signal'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        entryPrice: (json['entryPrice'] as num).toDouble(),
        stopLoss: (json['stopLoss'] as num).toDouble(),
        takeProfit: (json['takeProfit'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        resolved: json['resolved'] as bool? ?? false,
        win: json['win'] as bool?,
        resultReturnPercent: (json['resultReturnPercent'] as num?)?.toDouble(),
      );
}

/// Tracks real (non-backtested) prediction outcomes across app sessions so
/// the app can show an honest, evolving accuracy figure instead of only
/// ever displaying "here's today's signal" with no accountability.
class SignalTrackerService {
  static const _maxStored = 500;
  List<TrackedSignal> _cache = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.trackerStorageKey);
    if (raw != null) {
      final list = json.decode(raw) as List<dynamic>;
      _cache = list.map((e) => TrackedSignal.fromJson(e as Map<String, dynamic>)).toList();
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(_cache.map((t) => t.toJson()).toList());
    await prefs.setString(AppConstants.trackerStorageKey, raw);
  }

  /// Records a fresh (non-HOLD) prediction to be resolved later.
  Future<void> record(Prediction prediction) async {
    if (prediction.signal == SignalType.hold) return;
    await _ensureLoaded();
    _cache.add(TrackedSignal(
      symbol: prediction.symbol,
      signal: prediction.signal,
      timestamp: prediction.timestamp,
      entryPrice: prediction.currentPrice,
      stopLoss: prediction.stopLoss,
      takeProfit: prediction.takeProfit,
      confidence: prediction.confidence,
    ));
    if (_cache.length > _maxStored) {
      _cache = _cache.sublist(_cache.length - _maxStored);
    }
    await _persist();
  }

  /// Resolves any pending signals for [symbol] whose holding period has
  /// elapsed, using the freshest available candles to determine whether
  /// price hit the stop-loss, the take-profit, or neither.
  Future<void> resolvePending(String symbol, List<PriceData> recentPrices) async {
    await _ensureLoaded();
    if (recentPrices.isEmpty) return;

    final now = DateTime.now();
    var changed = false;

    for (final signal in _cache) {
      if (signal.resolved || signal.symbol != symbol) continue;

      final elapsedHours = now.difference(signal.timestamp).inHours;
      // klineInterval is 1h by default; treat resolution window in hours.
      if (elapsedHours < AppConstants.trackerResolutionCandles) continue;

      final candlesSinceEntry = recentPrices.where((p) => p.timestamp.millisecondsSinceEpoch >= signal.timestamp.millisecondsSinceEpoch).toList();
      final referencePrice = candlesSinceEntry.isNotEmpty ? candlesSinceEntry.last.close : recentPrices.last.close;

      bool win;
      double stopHit = signal.stopLoss;
      double targetHit = signal.takeProfit;
      double resultReturn;

      bool hitStop = false;
      bool hitTarget = false;
      for (final candle in candlesSinceEntry) {
        if (signal.signal == SignalType.buy) {
          if (stopHit > 0 && candle.low <= stopHit) {
            hitStop = true;
            break;
          }
          if (targetHit > 0 && candle.high >= targetHit) {
            hitTarget = true;
            break;
          }
        } else {
          if (stopHit > 0 && candle.high >= stopHit) {
            hitStop = true;
            break;
          }
          if (targetHit > 0 && candle.low <= targetHit) {
            hitTarget = true;
            break;
          }
        }
      }

      if (hitTarget) {
        win = true;
        resultReturn = signal.signal == SignalType.buy
            ? (targetHit - signal.entryPrice) / signal.entryPrice * 100
            : (signal.entryPrice - targetHit) / signal.entryPrice * 100;
      } else if (hitStop) {
        win = false;
        resultReturn = signal.signal == SignalType.buy
            ? (stopHit - signal.entryPrice) / signal.entryPrice * 100
            : (signal.entryPrice - stopHit) / signal.entryPrice * 100;
      } else {
        // Neither level hit within the window: resolve by simple direction.
        final rawReturn = (referencePrice - signal.entryPrice) / signal.entryPrice * 100;
        resultReturn = signal.signal == SignalType.buy ? rawReturn : -rawReturn;
        win = resultReturn > 0;
      }

      signal.resolved = true;
      signal.win = win;
      signal.resultReturnPercent = resultReturn;
      changed = true;
    }

    if (changed) await _persist();
  }

  /// Rolling win rate (0-100) and sample size over resolved signals for a
  /// symbol, most recent first. Returns (null, 0) if nothing resolved yet.
  Future<({double? winRate, int sampleSize})> winRateFor(String symbol, {int maxSamples = 50}) async {
    await _ensureLoaded();
    final resolved = _cache.where((t) => t.symbol == symbol && t.resolved).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final sample = resolved.take(maxSamples).toList();
    if (sample.isEmpty) return (winRate: null, sampleSize: 0);
    final wins = sample.where((t) => t.win == true).length;
    return (winRate: wins / sample.length * 100, sampleSize: sample.length);
  }

  Future<List<TrackedSignal>> history(String symbol) async {
    await _ensureLoaded();
    final list = _cache.where((t) => t.symbol == symbol).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> clear() async {
    _cache = [];
    await _persist();
  }
}
