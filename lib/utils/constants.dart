class AppConstants {
  static const String baseUrl = 'https://fapi.binance.com';
  static const String klinesEndpoint = '/fapi/v1/klines';
  static const String symbolEndpoint = '/fapi/v1/exchangeInfo';

  static const List<String> defaultSymbols = [
    'BTCUSDT',
    'ETHUSDT',
    'SOLUSDT',
    'BNBUSDT',
    'XRPUSDT',
  ];

  static const int klineLimit = 250;
  static const String klineInterval = '1h';

  static const String higherTimeframeInterval = '4h';
  static const int higherTimeframeLimit = 100;
  static const double higherTimeframeDisagreementPenalty = 0.75;

  static const List<String> higherTimeframes = ['4h', '1d'];
  static const Map<String, double> higherTimeframeWeights = {
    '4h': 1.0,
    '1d': 1.2,
  };
  static const double higherTimeframeAdxThreshold = 25.0;
  static const double higherTimeframeVolumeMinRatio = 1.0;

  static const int ema20Period = 20;
  static const int ema50Period = 50;
  static const int ema200Period = 200;
  static const int rsiPeriod = 14;
  static const double rsiOverbought = 70.0;
  static const double rsiOversold = 30.0;
  static const int macdFastPeriod = 12;
  static const int macdSlowPeriod = 26;
  static const int macdSignalPeriod = 9;
  static const int bollingerPeriod = 20;
  static const double bollingerStdDev = 2.0;
  static const int atrPeriod = 14;
  static const int obvLookback = 5;
  static const int adxPeriod = 14;
  static const int adxSmoothing = 14;
  static const double adxThreshold = 25.0;
  static const int cmfPeriod = 20;

  static const int swingPivotLookback = 10;
  static const double swingPivotProximityPercent = 0.005;
  static const List<double> fibonacciLevels = [0.236, 0.382, 0.5, 0.618];
  static const double fibProximityPercent = 0.005;

  static const double crisisVolatilityRatioThreshold = 0.30;
  static const double crisisAdxMin = 20.0;
  static const double crisisAdxMax = 40.0;

  static const double atrStopMultiplier = 1.5;
  static const double atrTargetMultiplier = 2.25;

  static const int backtestHoldingPeriodCandles = 6;
  static const int backtestWarmupCandles = 210;
  static const String backtestInterval = '1h';
  static const int backtestCandleLimit = 500;
  static const List<int> backtestHoldingPeriodOptions = [3, 6, 12, 24, 48, 72];
  static const List<int> backtestSetCountOptions = [5, 10, 15, 20, 25, 30];
  static const List<int> backtestCandlesPerSetOptions = [5, 10, 20, 30, 50, 100];
  static const List<String> backtestIntervals = [
    '1m',
    '5m',
    '15m',
    '1h',
    '4h',
    '1d',
  ];

  static const int trackerResolutionCandles = 6;
  static const String trackerStorageKey = 'signal_tracker_history_v1';

  static const int volumeLookbackPeriod = 14;
  static const int volumeSmaPeriod = 20;
  static const double volumeSpikeMultiplier = 1.5;
  static const double vrocPeriod = 14;
  static const int anchoredVwapLookback = 20;
  static const double volumeFilterCmfThreshold = 0;
  static const bool volumeFilterRequireSpikeOrCmf = true;

  static const String mlModelAssetPath = 'assets/ml_model.json';
  static const int mlFeatureCount = 33;
  static const double mlConfidenceBoost = 0.15;
  static const double mlConfidenceThreshold = 55.0;
  static const bool mlUseFallback = true;

  static const double ensembleWeightIndicator = 0.4;
  static const double ensembleWeightMl = 0.35;
  static const double ensembleWeightRegime = 0.25;
  static const double ensembleMinConfidence = 40.0;
  static const double ensembleScoreBoostThreshold = 60.0;
  static const double ensembleScorePenaltyThreshold = 40.0;
  static const double ensembleBoostFactor = 1.1;
  static const double ensemblePenaltyFactor = 0.9;

  static const double minConfidenceThreshold = 55.0;
  static const double crisisRegimeConfidencePenalty = 0.5;
  static const double volatilityFilterRatio = 0.05;
  static const double volatilityFilterConfidencePenalty = 0.7;
  static const bool timeFilterEnabled = false;
  static const int illiquidHourStart = 0;
  static const int illiquidHourEnd = 0;
}
