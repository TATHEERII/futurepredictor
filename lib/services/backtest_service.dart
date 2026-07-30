import '../models/backtest_result.dart';
import '../models/prediction.dart';
import '../models/price_data.dart';
import '../utils/constants.dart';
import 'prediction_service.dart';

/// Replays PredictionService against historical candles so signal quality
/// can be measured instead of assumed. Without this, there is no way to
/// know whether the indicator-voting strategy beats random guessing.
class BacktestService {
  final PredictionService _predictionService;

  BacktestService({PredictionService? predictionService}) : _predictionService = predictionService ?? PredictionService();

  /// Runs a walk-forward simulation: at each candle index, generate a
  /// signal using only data available up to that point (no lookahead),
  /// then check price `holdingPeriod` candles later to see if the
  /// direction was correct.
  ///
  /// When [setCount] and [candlesPerSet] are provided, runs in batched
  /// mode: the historical data is split into [setCount] chunks of
  /// [candlesPerSet] candles each. Each chunk generates at most one
  /// signal, so total signals <= [setCount].
  Future<BacktestResult> run(
    String symbol,
    List<PriceData> prices, {
    int holdingPeriod = AppConstants.backtestHoldingPeriodCandles,
    int warmup = AppConstants.backtestWarmupCandles,
    int setCount = 0,
    int candlesPerSet = 0,
  }) async {
    final trades = <BacktestTrade>[];

    if (setCount > 0 && candlesPerSet > 0) {
      return _runBatched(
        symbol,
        prices,
        setCount: setCount,
        candlesPerSet: candlesPerSet,
        holdingPeriod: holdingPeriod,
        warmup: warmup,
      );
    }

    final effectiveWarmup = warmup < prices.length ? warmup : (prices.length - holdingPeriod - 1);

    for (var i = effectiveWarmup; i < prices.length - holdingPeriod; i++) {
      final windowPrices = prices.sublist(0, i + 1);
      final prediction = await _predictionService.predict(symbol, windowPrices);

      if (prediction.signal == SignalType.hold) continue;

      final entryPrice = prices[i].close;
      final exitPrice = prices[i + holdingPeriod].close;
      final rawReturn = (exitPrice - entryPrice) / entryPrice * 100;
      final directionalReturn = prediction.signal == SignalType.buy ? rawReturn : -rawReturn;

      // If a stop-loss or take-profit would have been hit intrabar within
      // the holding window, resolve on whichever came first.
      double resolvedReturn = directionalReturn;
      bool win = directionalReturn > 0;

      if (prediction.stopLoss > 0 && prediction.takeProfit > 0) {
        for (var j = i + 1; j <= i + holdingPeriod && j < prices.length; j++) {
          final candle = prices[j];
          if (prediction.signal == SignalType.buy) {
            if (candle.low <= prediction.stopLoss) {
              resolvedReturn = (prediction.stopLoss - entryPrice) / entryPrice * 100;
              win = false;
              break;
            }
            if (candle.high >= prediction.takeProfit) {
              resolvedReturn = (prediction.takeProfit - entryPrice) / entryPrice * 100;
              win = true;
              break;
            }
          } else {
            if (candle.high >= prediction.stopLoss) {
              resolvedReturn = (entryPrice - prediction.stopLoss) / entryPrice * 100;
              win = false;
              break;
            }
            if (candle.low <= prediction.takeProfit) {
              resolvedReturn = (entryPrice - prediction.takeProfit) / entryPrice * 100;
              win = true;
              break;
            }
          }
        }
      }

      trades.add(BacktestTrade(
        timestamp: prediction.timestamp,
        signal: prediction.signal,
        entryPrice: entryPrice,
        exitPrice: exitPrice,
        returnPercent: resolvedReturn,
        win: win,
        confidenceAtEntry: prediction.confidence,
      ));
    }

    return _summarize(symbol, prices, trades, effectiveWarmup);
  }

  /// Batched backtest: splits [prices] into [setCount] chunks of
  /// [candlesPerSet] candles. Each chunk generates at most one signal.
  Future<BacktestResult> _runBatched(
    String symbol,
    List<PriceData> prices, {
    required int setCount,
    required int candlesPerSet,
    required int holdingPeriod,
    required int warmup,
  }) async {
    final trades = <BacktestTrade>[];

    // Need enough data: warmup + setCount * candlesPerSet + holdingPeriod.
    // If not enough data, reduce setCount to fit.
    final availableForSets = prices.length - warmup - holdingPeriod;
    if (availableForSets <= 0) {
      return _summarize(symbol, prices, trades, warmup);
    }

    final effectiveSetCount = setCount < availableForSets ~/ candlesPerSet
        ? setCount
        : availableForSets ~/ candlesPerSet;

    for (var s = 0; s < effectiveSetCount; s++) {
      final setEndIndex = warmup + (s + 1) * candlesPerSet - 1;
      if (setEndIndex >= prices.length) break;

      final exitIndex = setEndIndex + holdingPeriod;
      if (exitIndex >= prices.length) break;

      // Only data up to and including setEndIndex is visible.
      final windowPrices = prices.sublist(0, setEndIndex + 1);
      final prediction = await _predictionService.predict(symbol, windowPrices);

      if (prediction.signal == SignalType.hold) continue;

      final entryPrice = prices[setEndIndex].close;
      final exitPrice = prices[exitIndex].close;
      final rawReturn = (exitPrice - entryPrice) / entryPrice * 100;
      final directionalReturn = prediction.signal == SignalType.buy ? rawReturn : -rawReturn;

      double resolvedReturn = directionalReturn;
      bool win = directionalReturn > 0;

      if (prediction.stopLoss > 0 && prediction.takeProfit > 0) {
        for (var j = setEndIndex + 1; j <= exitIndex && j < prices.length; j++) {
          final candle = prices[j];
          if (prediction.signal == SignalType.buy) {
            if (candle.low <= prediction.stopLoss) {
              resolvedReturn = (prediction.stopLoss - entryPrice) / entryPrice * 100;
              win = false;
              break;
            }
            if (candle.high >= prediction.takeProfit) {
              resolvedReturn = (prediction.takeProfit - entryPrice) / entryPrice * 100;
              win = true;
              break;
            }
          } else {
            if (candle.high >= prediction.stopLoss) {
              resolvedReturn = (entryPrice - prediction.stopLoss) / entryPrice * 100;
              win = false;
              break;
            }
            if (candle.low <= prediction.takeProfit) {
              resolvedReturn = (entryPrice - prediction.takeProfit) / entryPrice * 100;
              win = true;
              break;
            }
          }
        }
      }

      trades.add(BacktestTrade(
        timestamp: prediction.timestamp,
        signal: prediction.signal,
        entryPrice: entryPrice,
        exitPrice: exitPrice,
        returnPercent: resolvedReturn,
        win: win,
        confidenceAtEntry: prediction.confidence,
      ));
    }

    return _summarize(symbol, prices, trades, warmup);
  }

  BacktestResult _summarize(String symbol, List<PriceData> prices, List<BacktestTrade> trades, int warmup) {
    final wins = trades.where((t) => t.win).length;
    final losses = trades.length - wins;
    final winRate = trades.isEmpty ? 0.0 : wins / trades.length * 100;

    final totalReturn = trades.fold<double>(0, (sum, t) => sum + t.returnPercent);
    final avgReturn = trades.isEmpty ? 0.0 : totalReturn / trades.length;

    // Simple equity curve to compute max drawdown, assuming trades are
    // taken sequentially and returns compound.
    double equity = 100;
    double peak = 100;
    double maxDrawdown = 0;
    for (final t in trades) {
      equity *= (1 + t.returnPercent / 100);
      if (equity > peak) peak = equity;
      final drawdown = (peak - equity) / peak * 100;
      if (drawdown > maxDrawdown) maxDrawdown = drawdown;
    }

    final buyAndHoldReturn = (warmup < prices.length && prices.isNotEmpty)
        ? (prices.last.close - prices[warmup].close) / prices[warmup].close * 100
        : 0.0;

    // A crude Sharpe-like ratio: mean return / stddev of returns, unannualized.
    double sharpe = 0;
    if (trades.length > 1) {
      final mean = avgReturn;
      final variance = trades.fold<double>(0, (sum, t) => sum + (t.returnPercent - mean) * (t.returnPercent - mean)) / trades.length;
      final stdDev = variance <= 0 ? 0.0 : _sqrt(variance);
      sharpe = stdDev == 0 ? 0 : mean / stdDev;
    }

    return BacktestResult(
      symbol: symbol,
      totalSignals: trades.length,
      buySignals: trades.where((t) => t.signal == SignalType.buy).length,
      sellSignals: trades.where((t) => t.signal == SignalType.sell).length,
      holdSignals: 0,
      wins: wins,
      losses: losses,
      winRate: winRate,
      averageReturnPercent: avgReturn,
      totalReturnPercent: totalReturn,
      maxDrawdownPercent: maxDrawdown,
      buyAndHoldReturnPercent: buyAndHoldReturn,
      sharpeLikeRatio: sharpe,
      trades: trades,
    );
  }

  double _sqrt(double value) {
    if (value <= 0) return 0;
    double x = value;
    double prev;
    do {
      prev = x;
      x = (x + value / x) / 2;
    } while ((prev - x).abs() > 1e-9);
    return x;
  }
}
