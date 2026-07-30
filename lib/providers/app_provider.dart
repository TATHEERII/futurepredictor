import 'dart:async';
import 'package:flutter/material.dart';
import '../models/backtest_result.dart';
import '../models/prediction.dart';
import '../models/price_data.dart';
import '../services/api_service.dart';
import '../services/backtest_service.dart';
import '../services/prediction_service.dart';
import '../services/signal_tracker_service.dart';
import '../utils/constants.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final PredictionService _predictionService = PredictionService();
  final BacktestService _backtestService = BacktestService();
  final SignalTrackerService _signalTracker = SignalTrackerService();

  bool _isRunning = false;
  Timer? _timer;

  String _selectedSymbol = AppConstants.defaultSymbols[0];
  List<PriceData> _priceData = [];
  Prediction? _currentPrediction;
  final _predictionHistory = <Prediction>[];
  bool _isLoading = false;
  String _errorMessage = '';

  double? _liveWinRate;
  int _liveSampleSize = 0;

  BacktestResult? _backtestResult;
  bool _isBacktesting = false;
  String _backtestInterval = AppConstants.backtestInterval;
  int _backtestCandleLimit = AppConstants.backtestCandleLimit;
  int _backtestHoldingPeriod = AppConstants.backtestHoldingPeriodCandles;
  int _backtestSetCount = AppConstants.backtestSetCountOptions[1];
  int _backtestCandlesPerSet = AppConstants.backtestCandlesPerSetOptions[1];

  bool get isRunning => _isRunning;
  String get selectedSymbol => _selectedSymbol;
  List<PriceData> get priceData => _priceData;
  Prediction? get currentPrediction => _currentPrediction;
  List<Prediction> get predictionHistory => _predictionHistory;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  double? get liveWinRate => _liveWinRate;
  int get liveSampleSize => _liveSampleSize;
  BacktestResult? get backtestResult => _backtestResult;
  bool get isBacktesting => _isBacktesting;
  String get backtestInterval => _backtestInterval;
  int get backtestCandleLimit => _backtestCandleLimit;
  int get backtestHoldingPeriod => _backtestHoldingPeriod;
  int get backtestSetCount => _backtestSetCount;
  int get backtestCandlesPerSet => _backtestCandlesPerSet;

  List<String> get availableSymbols => AppConstants.defaultSymbols;

  void setSymbol(String symbol) {
    _selectedSymbol = symbol;
    _predictionHistory.clear();
    _backtestResult = null;
    _liveWinRate = null;
    _liveSampleSize = 0;
    notifyListeners();
    _refreshLiveWinRate();
  }

  Future<void> _refreshLiveWinRate() async {
    final result = await _signalTracker.winRateFor(_selectedSymbol);
    _liveWinRate = result.winRate;
    _liveSampleSize = result.sampleSize;
    notifyListeners();
  }

  Future<void> fetchData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _priceData = await _apiService.fetchKlines(_selectedSymbol);

      // Resolve any previously-recorded live signals now that fresh
      // candles are available, then refresh the rolling win rate.
      await _signalTracker.resolvePending(_selectedSymbol, _priceData);
      final winRateResult = await _signalTracker.winRateFor(_selectedSymbol);
      _liveWinRate = winRateResult.winRate;
      _liveSampleSize = winRateResult.sampleSize;

      // Best-effort higher-timeframe fetch for multi-timeframe confirmation.
      // If it fails, fall back to single-timeframe prediction rather than
      // failing the whole refresh.
      Map<String, List<PriceData>>? higherTimeframePrices;
      try {
        higherTimeframePrices = await _apiService.fetchAllHigherTimeframes(_selectedSymbol);
      } catch (_) {
        higherTimeframePrices = null;
      }

      _currentPrediction = await _predictionService.predict(
        _selectedSymbol,
        _priceData,
        higherTimeframePrices: higherTimeframePrices,
        liveWinRate: _liveWinRate,
        liveSampleSize: _liveSampleSize,
      );

      _predictionHistory.insert(0, _currentPrediction!);
      if (_predictionHistory.length > 50) {
        _predictionHistory.removeLast();
      }

      // Record this fresh signal so its outcome can be checked later.
      await _signalTracker.record(_currentPrediction!);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Replays historical candles through PredictionService to measure
  /// whether the signal logic actually has an edge, instead of assuming it
  /// does. Runs on already-fetched price data, or fetches a longer history
  /// first if needed.
  void setBacktestInterval(String interval) {
    _backtestInterval = interval;
    notifyListeners();
  }

  void setBacktestCandleLimit(int limit) {
    _backtestCandleLimit = limit;
    notifyListeners();
  }

  void setBacktestHoldingPeriod(int period) {
    _backtestHoldingPeriod = period;
    notifyListeners();
  }

  void setBacktestSetCount(int count) {
    _backtestSetCount = count;
    notifyListeners();
  }

  void setBacktestCandlesPerSet(int count) {
    _backtestCandlesPerSet = count;
    notifyListeners();
  }

  Future<void> runBacktest() async {
    _isBacktesting = true;
    _errorMessage = '';
    notifyListeners();

    try {
      var historyForBacktest = _priceData;
      if (historyForBacktest.length < AppConstants.backtestWarmupCandles + _backtestHoldingPeriod + 20) {
        historyForBacktest = await _apiService.fetchKlines(
          _selectedSymbol,
          interval: _backtestInterval,
          limit: _backtestCandleLimit,
        );
      }
      _backtestResult = await _backtestService.run(
        _selectedSymbol,
        historyForBacktest,
        holdingPeriod: _backtestHoldingPeriod,
        warmup: AppConstants.backtestWarmupCandles,
        setCount: _backtestSetCount,
        candlesPerSet: _backtestCandlesPerSet,
      );
    } catch (e) {
      _errorMessage = 'Backtest failed: $e';
    } finally {
      _isBacktesting = false;
      notifyListeners();
    }
  }

  void startBot() {
    _isRunning = true;
    notifyListeners();
    fetchData();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      fetchData();
    });
  }

  void stopBot() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _apiService.dispose();
    super.dispose();
  }
}
