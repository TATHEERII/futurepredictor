import 'prediction.dart';

/// Outcome of a single simulated signal during a backtest run.
class BacktestTrade {
  final DateTime timestamp;
  final SignalType signal;
  final double entryPrice;
  final double exitPrice;
  final double returnPercent;
  final bool win;
  final double confidenceAtEntry;

  BacktestTrade({
    required this.timestamp,
    required this.signal,
    required this.entryPrice,
    required this.exitPrice,
    required this.returnPercent,
    required this.win,
    required this.confidenceAtEntry,
  });
}

/// Aggregate statistics from replaying PredictionService against historical
/// candles, so signal quality can be measured instead of assumed.
class BacktestResult {
  final String symbol;
  final int totalSignals;
  final int buySignals;
  final int sellSignals;
  final int holdSignals;
  final int wins;
  final int losses;
  final double winRate;
  final double averageReturnPercent;
  final double totalReturnPercent;
  final double maxDrawdownPercent;
  final double buyAndHoldReturnPercent;
  final double sharpeLikeRatio;
  final List<BacktestTrade> trades;

  BacktestResult({
    required this.symbol,
    required this.totalSignals,
    required this.buySignals,
    required this.sellSignals,
    required this.holdSignals,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.averageReturnPercent,
    required this.totalReturnPercent,
    required this.maxDrawdownPercent,
    required this.buyAndHoldReturnPercent,
    required this.sharpeLikeRatio,
    required this.trades,
  });

  /// True only if the strategy beat a naive buy-and-hold over the same
  /// window AND had a positive win rate. This is the single most important
  /// number in the whole app: it tells you whether the indicator-voting
  /// logic is actually worth using.
  bool get beatsBuyAndHold => totalReturnPercent > buyAndHoldReturnPercent;
}
