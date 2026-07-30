
import 'multi_timeframe_confirmation.dart';

enum SignalType { buy, sell, hold }

enum MarketRegime { trending, ranging, crisis, unknown }

class Prediction {
  final SignalType signal;
  final double confidence;
  final String symbol;
  final DateTime timestamp;
  final double currentPrice;
  final double changePercent;

  final double ema20;
  final double ema50;
  final double ema200;

  final double rsi;
  final double macdLine;
  final double macdSignal;
  final double macdHistogram;

  final double atr;
  final double bollingerUpper;
  final double bollingerLower;

  final double obv;
  final bool obvRising;
  final double cmf;

  final bool higherHigh;
  final bool lowerLow;

  final bool bullishEngulfing;
  final bool bearishEngulfing;
  final bool hammer;
  final bool shootingStar;

  final double adx;
  final bool adxTrending;
  final double adxPlusDi;
  final double adxMinusDi;
  final MarketRegime regime;
  final Map<MarketRegime, double>? regimeProbabilities;

  final double stopLoss;
  final double takeProfit;
  final double riskRewardRatio;

  final bool? higherTimeframeAligned;
  final List<MultiTimeframeConfirmation>? multiTimeframeConfirmations;

  final double? historicalWinRate;
  final int historicalSampleSize;

  final bool isNearSupport;
  final bool isNearResistance;
  final bool isNearFibLevel;
  final double distanceToNearestPivot;
  final List<double> supportLevels;
  final List<double> resistanceLevels;
  final List<double> fibLevels;
  final double? nearestSupport;
  final double? nearestResistance;
  final bool? hasBullishOrderBlock;
  final bool? hasBearishOrderBlock;
  final double? bullishOrderBlockPrice;
  final double? bearishOrderBlockPrice;

  final bool volumeSpike;
  final double? vroc;
  final double? vwap;
  final double trendScore;

  final double probabilityUp;
  final double probabilityDown;
  final double probabilitySideways;

  final String? modelVersion;
  final Map<SignalType, double>? modelProbability;

  final double ensembleScore;
  final double finalConfidence;

  final List<String> filterReasons;

  Prediction({
    required this.signal,
    required this.confidence,
    required this.symbol,
    required this.timestamp,
    required this.currentPrice,
    required this.changePercent,
    required this.ema20,
    required this.ema50,
    required this.ema200,
    required this.rsi,
    required this.macdLine,
    required this.macdSignal,
    required this.macdHistogram,
    required this.atr,
    required this.bollingerUpper,
    required this.bollingerLower,
    required this.obv,
    required this.obvRising,
    required this.cmf,
    required this.higherHigh,
    required this.lowerLow,
    required this.bullishEngulfing,
    required this.bearishEngulfing,
    required this.hammer,
    required this.shootingStar,
    required this.adx,
    required this.adxTrending,
    required this.adxPlusDi,
    required this.adxMinusDi,
    required this.regime,
    this.regimeProbabilities,
    required this.stopLoss,
    required this.takeProfit,
    required this.riskRewardRatio,
    required this.probabilityUp,
    required this.probabilityDown,
    required this.probabilitySideways,
    this.higherTimeframeAligned,
    this.multiTimeframeConfirmations,
    this.historicalWinRate,
    this.historicalSampleSize = 0,
    required this.isNearSupport,
    required this.isNearResistance,
    required this.isNearFibLevel,
    required this.distanceToNearestPivot,
    required this.supportLevels,
    required this.resistanceLevels,
    required this.fibLevels,
    this.nearestSupport,
    this.nearestResistance,
    this.hasBullishOrderBlock,
    this.hasBearishOrderBlock,
    this.bullishOrderBlockPrice,
    this.bearishOrderBlockPrice,
    required this.volumeSpike,
    required this.vroc,
    required this.vwap,
    required this.trendScore,
    this.modelVersion,
    this.modelProbability,
    this.ensembleScore = 50.0,
    this.finalConfidence = 50.0,
    this.filterReasons = const [],
  });

  String get signalLabel {
    switch (signal) {
      case SignalType.buy:
        return 'BUY';
      case SignalType.sell:
        return 'SELL';
      case SignalType.hold:
        return 'HOLD';
    }
  }

  String get signalColor {
    switch (signal) {
      case SignalType.buy:
        return '#00E676';
      case SignalType.sell:
        return '#FF1744';
      case SignalType.hold:
        return '#FFC107';
    }
  }

  String get regimeLabel {
    switch (regime) {
      case MarketRegime.trending:
        return 'Trending';
      case MarketRegime.ranging:
        return 'Ranging';
      case MarketRegime.crisis:
        return 'Crisis';
      case MarketRegime.unknown:
        return 'Unknown';
    }
  }

  String get bollingerStatus {
    if (currentPrice > bollingerUpper) return 'Overbought';
    if (currentPrice < bollingerLower) return 'Oversold';
    return 'Mid';
  }

  Map<String, dynamic> toTrackingJson() => {
        'symbol': symbol,
        'signal': signal.name,
        'timestamp': timestamp.toIso8601String(),
        'entryPrice': currentPrice,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'confidence': confidence,
      };
}
