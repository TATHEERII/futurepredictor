import 'dart:math';
import '../models/price_data.dart';
import '../models/prediction.dart';
import '../models/multi_timeframe_confirmation.dart';
import '../utils/constants.dart';
import 'regime_hmm_service.dart';
import 'ml_model_service.dart';
import 'meta_learner_service.dart';

class PredictionService {
  final RegimeHmmService _regimeHmmService = RegimeHmmService();
  final MlModelService _mlModelService = MlModelService();
  final MetaLearnerService _metaLearnerService = MetaLearnerService();
  bool _mlModelLoaded = false;

  PredictionService() {
    _mlModelService.loadModel().then((_) {
      _mlModelLoaded = true;
    });
  }
  double calculateEma(List<PriceData> prices, int period) {
    if (prices.isEmpty) return 0;
    if (prices.length < period) return calculateSma(prices, prices.length);
    final multiplier = 2 / (period + 1);
    double ema = calculateSma(prices.sublist(0, period), period);
    for (var i = period; i < prices.length; i++) {
      ema = (prices[i].close - ema) * multiplier + ema;
    }
    return ema;
  }

  double calculateEmaOnValues(List<double> values, int period) {
    if (values.isEmpty) return 0;
    if (values.length < period) return values.fold<double>(0, (sum, v) => sum + v) / values.length;
    final multiplier = 2 / (period + 1);
    double ema = values.sublist(0, period).fold<double>(0, (sum, v) => sum + v) / period;
    for (var i = period; i < values.length; i++) {
      ema = (values[i] - ema) * multiplier + ema;
    }
    return ema;
  }

  double calculateSma(List<PriceData> prices, int period) {
    if (prices.length < period) return 0;
    final slice = prices.sublist(prices.length - period);
    return slice.fold<double>(0, (sum, p) => sum + p.close) / period;
  }

  double calculateSmaOn(List<double> values, int period) {
    if (values.length < period) return values.fold<double>(0, (sum, v) => sum + v) / values.length;
    final slice = values.sublist(values.length - period);
    return slice.fold<double>(0, (sum, v) => sum + v) / period;
  }

  double calculateRsi(List<PriceData> prices, {int period = 14}) {
    if (prices.length < period + 1) return 50;

    final gains = <double>[];
    final losses = <double>[];

    for (var i = prices.length - period; i < prices.length; i++) {
      final diff = prices[i].close - prices[i - 1].close;
      if (diff > 0) {
        gains.add(diff);
        losses.add(0);
      } else {
        gains.add(0);
        losses.add(diff.abs());
      }
    }

    final avgGain = gains.fold<double>(0, (sum, g) => sum + g) / period;
    final avgLoss = losses.fold<double>(0, (sum, l) => sum + l) / period;

    if (avgLoss == 0) return 100;

    return 100 - (100 / (1 + (avgGain / avgLoss)));
  }

  double calculateMacdLine(List<PriceData> prices) {
    final emaFast = calculateEma(prices, AppConstants.macdFastPeriod);
    final emaSlow = calculateEma(prices, AppConstants.macdSlowPeriod);
    return emaFast - emaSlow;
  }

  double calculateMacdSignal(List<PriceData> prices) {
    final macdValues = <double>[];
    for (var i = AppConstants.macdSlowPeriod; i <= prices.length; i++) {
      final slice = prices.sublist(0, i);
      macdValues.add(calculateMacdLine(slice));
    }
    if (macdValues.length < AppConstants.macdSignalPeriod) {
      return macdValues.isNotEmpty ? macdValues.last : 0;
    }
    return calculateEmaOnValues(macdValues, AppConstants.macdSignalPeriod);
  }

  double calculateBollingerMiddle(List<PriceData> prices) {
    return calculateSma(prices, AppConstants.bollingerPeriod);
  }

  double calculateBollingerStdDev(List<PriceData> prices) {
    if (prices.length < AppConstants.bollingerPeriod) return 0;
    final middle = calculateBollingerMiddle(prices);
    final slice = prices.sublist(prices.length - AppConstants.bollingerPeriod);
    final squaredDiffs = slice.map((p) => pow(p.close - middle, 2));
    final variance = squaredDiffs.fold<double>(0, (sum, d) => sum + d) / AppConstants.bollingerPeriod;
    return sqrt(variance);
  }

  double calculateBollingerUpper(List<PriceData> prices) {
    return calculateBollingerMiddle(prices) + calculateBollingerStdDev(prices) * AppConstants.bollingerStdDev;
  }

  double calculateBollingerLower(List<PriceData> prices) {
    return calculateBollingerMiddle(prices) - calculateBollingerStdDev(prices) * AppConstants.bollingerStdDev;
  }

  double calculateAtr(List<PriceData> prices) {
    final period = AppConstants.atrPeriod;
    if (prices.length < period + 1) return 0;

    final trList = <double>[];
    for (var i = 1; i < prices.length; i++) {
      final highLow = prices[i].high - prices[i].low;
      final highPrevClose = (prices[i].high - prices[i - 1].close).abs();
      final lowPrevClose = (prices[i].low - prices[i - 1].close).abs();
      trList.add([highLow, highPrevClose, lowPrevClose].reduce((a, b) => a > b ? a : b));
    }

    if (trList.length < period) return 0;
    var atr = trList.sublist(0, period).fold<double>(0, (sum, tr) => sum + tr) / period;

    for (var i = period; i < trList.length; i++) {
      atr = (atr * (period - 1) + trList[i]) / period;
    }

    return atr;
  }

  double calculateObv(List<PriceData> prices) {
    if (prices.length < 2) return 0;
    double obv = 0;
    for (var i = 1; i < prices.length; i++) {
      if (prices[i].close > prices[i - 1].close) {
        obv += prices[i].volume;
      } else if (prices[i].close < prices[i - 1].close) {
        obv -= prices[i].volume;
      }
    }
    return obv;
  }

  bool isObvRising(List<PriceData> prices) {
    if (prices.length < AppConstants.obvLookback + 1) return false;
    final currentObv = calculateObv(prices);
    final prevPrices = prices.sublist(0, prices.length - AppConstants.obvLookback);
    final prevObv = calculateObv(prevPrices);
    return currentObv > prevObv;
  }

  ({double adx, bool adxTrending, double plusDi, double minusDi}) calculateAdx(List<PriceData> prices) {
    final period = AppConstants.adxPeriod;
    if (prices.length < period + 1) {
      return (adx: 0, adxTrending: false, plusDi: 0, minusDi: 0);
    }

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

    if (trList.length < period) {
      return (adx: 0, adxTrending: false, plusDi: 0, minusDi: 0);
    }

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

    if (dxValues.isEmpty) {
      return (adx: 0, adxTrending: false, plusDi: 0, minusDi: 0);
    }

    if (dxValues.length < AppConstants.adxSmoothing) {
      final adx = dxValues.fold<double>(0, (sum, v) => sum + v) / dxValues.length;
      final plusDi = smoothedPlusDm / smoothedTr * 100;
      final minusDi = smoothedMinusDm / smoothedTr * 100;
      return (adx: adx, adxTrending: adx > AppConstants.adxThreshold, plusDi: plusDi, minusDi: minusDi);
    }

    var adx = dxValues.sublist(0, AppConstants.adxSmoothing).fold<double>(0, (sum, v) => sum + v) / AppConstants.adxSmoothing;

    for (var i = AppConstants.adxSmoothing; i < dxValues.length; i++) {
      adx = (adx * (AppConstants.adxSmoothing - 1) + dxValues[i]) / AppConstants.adxSmoothing;
    }

    final plusDi = smoothedPlusDm / smoothedTr * 100;
    final minusDi = smoothedMinusDm / smoothedTr * 100;

    return (adx: adx, adxTrending: adx > AppConstants.adxThreshold, plusDi: plusDi, minusDi: minusDi);
  }

  double calculateCmf(List<PriceData> prices, {int period = 20}) {
    if (prices.length < period) return 0;
    final slice = prices.sublist(prices.length - period);
    double mfVolumeSum = 0;
    double volumeSum = 0;
    for (final p in slice) {
      final range = p.high - p.low;
      if (range == 0) continue;
      final mfMultiplier = ((p.close - p.low) - (p.high - p.close)) / range;
      mfVolumeSum += mfMultiplier * p.volume;
      volumeSum += p.volume;
    }
    if (volumeSum == 0) return 0;
    return mfVolumeSum / volumeSum;
  }

  bool _isHammer(PriceData c) {
    final range = c.high - c.low;
    if (range == 0) return false;
    final body = (c.close - c.open).abs();
    final lowerWick = min(c.close, c.open) - c.low;
    final upperWick = c.high - max(c.close, c.open);
    return lowerWick > body * 2 && upperWick < body * 0.5 && body / range < 0.4;
  }

  bool _isShootingStar(PriceData c) {
    final range = c.high - c.low;
    if (range == 0) return false;
    final body = (c.close - c.open).abs();
    final upperWick = c.high - max(c.close, c.open);
    final lowerWick = min(c.close, c.open) - c.low;
    return upperWick > body * 2 && lowerWick < body * 0.5 && body / range < 0.4;
  }

  bool _isBullishEngulfing(PriceData prev, PriceData curr) {
    final prevBearish = prev.close < prev.open;
    final currBullish = curr.close > curr.open;
    return prevBearish && currBullish && curr.close >= prev.open && curr.open <= prev.close;
  }

  bool _isBearishEngulfing(PriceData prev, PriceData curr) {
    final prevBullish = prev.close > prev.open;
    final currBearish = curr.close < curr.open;
    return prevBullish && currBearish && curr.open >= prev.close && curr.close <= prev.open;
  }

  bool _isHigherHigh(List<PriceData> prices, {int period = 20}) {
    if (prices.length < period + 1) return false;
    final currentHigh = prices.last.high;
    final prevHighs = prices.sublist(prices.length - period - 1, prices.length - 1).map((p) => p.high);
    return currentHigh > prevHighs.reduce((a, b) => a > b ? a : b);
  }

  bool _isLowerLow(List<PriceData> prices, {int period = 20}) {
    if (prices.length < period + 1) return false;
    final currentLow = prices.last.low;
    final prevLows = prices.sublist(prices.length - period - 1, prices.length - 1).map((p) => p.low);
    return currentLow < prevLows.reduce((a, b) => a < b ? a : b);
  }

  Future<({MarketRegime regime, Map<MarketRegime, double> regimeProbs})> _detectRegime(
    bool adxTrending,
    double adx,
    double atr,
    double price,
    List<PriceData> prices,
  ) async {
    final volatilityRatio = price > 0 ? atr / price : 0;
    final isCrisis = volatilityRatio > AppConstants.crisisVolatilityRatioThreshold &&
        adx >= AppConstants.crisisAdxMin &&
        adx <= AppConstants.crisisAdxMax;

    if (isCrisis) {
      return (
        regime: MarketRegime.crisis,
        regimeProbs: {
          MarketRegime.trending: 0.0,
          MarketRegime.ranging: 0.0,
          MarketRegime.crisis: 1.0,
          MarketRegime.unknown: 0.0,
        },
      );
    }

    final hmmProbs = await _regimeHmmService.computeRegimeProbabilities(prices);
    final trendingProb = hmmProbs[MarketRegime.trending] ?? 0.0;
    final rangingProb = hmmProbs[MarketRegime.ranging] ?? 0.0;

    MarketRegime regime;
    if (trendingProb > rangingProb) {
      regime = MarketRegime.trending;
    } else if (rangingProb > trendingProb) {
      regime = MarketRegime.ranging;
    } else {
      regime = adxTrending ? MarketRegime.trending : MarketRegime.ranging;
    }

    final total = trendingProb + rangingProb;
    final finalProbs = <MarketRegime, double>{
      MarketRegime.trending: total > 0 ? trendingProb / total : 0.5,
      MarketRegime.ranging: total > 0 ? rangingProb / total : 0.5,
      MarketRegime.crisis: 0.0,
      MarketRegime.unknown: 0.0,
    };

    return (regime: regime, regimeProbs: finalProbs);
  }

  ({double stopLoss, double takeProfit, double riskReward}) _riskLevels(
    SignalType signal,
    double price,
    double atr,
  ) {
    if (atr <= 0 || signal == SignalType.hold) {
      return (stopLoss: 0.0, takeProfit: 0.0, riskReward: 0.0);
    }
    final stopDistance = atr * AppConstants.atrStopMultiplier;
    final targetDistance = atr * AppConstants.atrTargetMultiplier;

    final stopLoss = signal == SignalType.buy ? price - stopDistance : price + stopDistance;
    final takeProfit = signal == SignalType.buy ? price + targetDistance : price - targetDistance;
    final riskReward = stopDistance == 0 ? 0.0 : targetDistance / stopDistance;

    return (stopLoss: stopLoss, takeProfit: takeProfit, riskReward: riskReward);
  }

double calculateVolumeSma(List<PriceData> prices, {int period = 20}) {
    if (prices.length < period) return 0;
    final slice = prices.sublist(prices.length - period);
    return slice.fold<double>(0, (sum, p) => sum + p.volume) / period;
  }

  double calculateVroc(List<PriceData> prices, {int period = 14}) {
    if (prices.length < period + 1) return 0;
    final currentVolume = prices.last.volume;
    final pastVolume = prices[prices.length - period - 1].volume;
    if (pastVolume == 0) return 0;
    return ((currentVolume - pastVolume) / pastVolume) * 100;
  }

  double? calculateAnchoredVwap(List<PriceData> prices, {int lookback = 20}) {
    if (prices.length < lookback) return null;
    final slice = prices.sublist(prices.length - lookback);
    double cumulativeTypicalVolume = 0;
    double cumulativeVolume = 0;
    for (final p in slice) {
      final typicalPrice = (p.high + p.low + p.close) / 3;
      cumulativeTypicalVolume += typicalPrice * p.volume;
      cumulativeVolume += p.volume;
    }
    if (cumulativeVolume == 0) return null;
    return cumulativeTypicalVolume / cumulativeVolume;
  }

  bool _isVolumeSpike(List<PriceData> prices) {
    final currentVolume = prices.last.volume;
    final volumeSma = calculateVolumeSma(prices, period: AppConstants.volumeSmaPeriod);
    if (volumeSma <= 0) return false;
    return currentVolume > volumeSma * AppConstants.volumeSpikeMultiplier;
  }

  double _calculateVolumeSma(List<PriceData> prices, int period) {
    if (prices.length < period) return 0;
    final slice = prices.sublist(prices.length - period);
    return slice.fold<double>(0, (sum, p) => sum + p.volume) / period;
  }

  bool _isObvRisingFor(List<PriceData> prices, {int lookback = 5}) {
    if (prices.length < lookback + 1) return false;
    final currentObv = calculateObv(prices);
    final prevPrices = prices.sublist(0, prices.length - lookback);
    final prevObv = calculateObv(prevPrices);
    return currentObv > prevObv;
  }

  MultiTimeframeConfirmation _computeMultiTimeframeConfirmation(
    List<PriceData> higherTfPrices,
    SignalType signal,
  ) {
    if (higherTfPrices.length < AppConstants.ema200Period) {
      return MultiTimeframeConfirmation(
        timeframe: '',
        trendAligned: false,
        adxAligned: false,
        volumeConfirmed: false,
        obvAligned: false,
        adx: 0,
        isTrending: false,
        volumeRatio: 0,
      );
    }

    final ema50 = calculateEma(higherTfPrices, AppConstants.ema50Period);
    final ema200 = calculateEma(higherTfPrices, AppConstants.ema200Period);
    final trendAligned = signal == SignalType.buy ? ema50 > ema200 : signal == SignalType.sell ? ema50 < ema200 : true;

    final adxResult = calculateAdx(higherTfPrices);
    final isTrending = adxResult.adx > AppConstants.higherTimeframeAdxThreshold;
    final adxAligned = isTrending &&
        (signal == SignalType.buy ? adxResult.plusDi > adxResult.minusDi : signal == SignalType.sell ? adxResult.minusDi > adxResult.plusDi : true);

    final volumeSma = _calculateVolumeSma(higherTfPrices, 20);
    final currentVolume = higherTfPrices.last.volume;
    final volumeRatio = volumeSma > 0 ? (currentVolume / volumeSma).toDouble() : 0.0;
    final volumeConfirmed = volumeRatio >= AppConstants.higherTimeframeVolumeMinRatio;

    final obvRising = _isObvRisingFor(higherTfPrices);
    final obvAligned = signal == SignalType.hold ? true : obvRising == (signal == SignalType.buy);

    return MultiTimeframeConfirmation(
      timeframe: '',
      trendAligned: trendAligned,
      adxAligned: adxAligned,
      volumeConfirmed: volumeConfirmed,
      obvAligned: obvAligned,
      adx: adxResult.adx,
      isTrending: isTrending,
      volumeRatio: volumeRatio,
    );
  }

  bool? higherTimeframeBullish(List<PriceData> higherTimeframePrices) {
    if (higherTimeframePrices.length < AppConstants.ema200Period) return null;
    final ema50 = calculateEma(higherTimeframePrices, AppConstants.ema50Period);
    final ema200 = calculateEma(higherTimeframePrices, AppConstants.ema200Period);
    return ema50 > ema200;
  }

  List<double> _findSwingHighs(List<PriceData> prices, {int lookback = 10}) {
    final highs = <double>[];
    if (prices.length < lookback * 2 + 1) return highs;
    for (var i = lookback; i < prices.length - lookback; i++) {
      bool isSwing = true;
      for (var j = 1; j <= lookback; j++) {
        if (prices[i].high <= prices[i - j].high || prices[i].high <= prices[i + j].high) {
          isSwing = false;
          break;
        }
      }
      if (isSwing) highs.add(prices[i].high);
    }
    return highs;
  }

  List<double> _findSwingLows(List<PriceData> prices, {int lookback = 10}) {
    final lows = <double>[];
    if (prices.length < lookback * 2 + 1) return lows;
    for (var i = lookback; i < prices.length - lookback; i++) {
      bool isSwing = true;
      for (var j = 1; j <= lookback; j++) {
        if (prices[i].low >= prices[i - j].low || prices[i].low >= prices[i + j].low) {
          isSwing = false;
          break;
        }
      }
      if (isSwing) lows.add(prices[i].low);
    }
    return lows;
  }

  List<double> _computeFibonacciLevels(double high, double low) {
    final levels = <double>[];
    final diff = high - low;
    for (final ratio in AppConstants.fibonacciLevels) {
      levels.add(high - diff * ratio);
    }
    levels.sort();
    return levels;
  }

  bool _isNearLevel(double price, double level, double percent) {
    if (level <= 0) return false;
    return (price - level).abs() / level <= percent;
  }

  ({
    bool hasBullishOrderBlock,
    bool hasBearishOrderBlock,
    double? bullishOrderBlockPrice,
    double? bearishOrderBlockPrice,
  }) _detectOrderBlocks(List<PriceData> prices) {
    if (prices.length < 3) {
      return (
        hasBullishOrderBlock: false,
        hasBearishOrderBlock: false,
        bullishOrderBlockPrice: null,
        bearishOrderBlockPrice: null,
      );
    }

    double? bullishObPrice;
    double? bearishObPrice;
    bool foundBullish = false;
    bool foundBearish = false;

    for (var i = 2; i < prices.length; i++) {
      final prev = prices[i - 2];
      final curr = prices[i - 1];
      final next = prices[i];

      if (!foundBullish &&
          prev.close < prev.open &&
          curr.close < curr.open &&
          next.close > next.open &&
          next.close > prev.open) {
        bullishObPrice = prev.close;
        foundBullish = true;
      }

      if (!foundBearish &&
          prev.close > prev.open &&
          curr.close > curr.open &&
          next.close < next.open &&
          next.close < prev.open) {
        bearishObPrice = prev.close;
        foundBearish = true;
      }
    }

    return (
      hasBullishOrderBlock: foundBullish,
      hasBearishOrderBlock: foundBearish,
      bullishOrderBlockPrice: bullishObPrice,
      bearishOrderBlockPrice: bearishObPrice,
    );
  }

  Future<Prediction> predict(
    String symbol,
    List<PriceData> prices, {
    Map<String, List<PriceData>>? higherTimeframePrices,
    double? liveWinRate,
    int liveSampleSize = 0,
  }) async {
    final requiredForPrediction = max(
      AppConstants.ema200Period,
      max(
        AppConstants.adxPeriod + AppConstants.adxSmoothing,
        max(
          AppConstants.macdSlowPeriod + AppConstants.macdSignalPeriod,
          max(
            AppConstants.bollingerPeriod,
            max(
              AppConstants.atrPeriod + 1,
              AppConstants.cmfPeriod,
            ),
          ),
        ),
      ),
    );

    if (prices.length < requiredForPrediction + 1) {
      return _emptyPrediction(symbol, prices);
    }

    final ema20 = calculateEma(prices, AppConstants.ema20Period);
    final ema50 = calculateEma(prices, AppConstants.ema50Period);
    final ema200 = calculateEma(prices, AppConstants.ema200Period);
    final rsi = calculateRsi(prices, period: AppConstants.rsiPeriod);
    final macdLine = calculateMacdLine(prices);
    final macdSignal = calculateMacdSignal(prices);
    final macdHistogram = macdLine - macdSignal;
    final bollingerUpper = calculateBollingerUpper(prices);
    final bollingerLower = calculateBollingerLower(prices);
    final atr = calculateAtr(prices);
    final obv = calculateObv(prices);
    final obvRising = isObvRising(prices);
    final cmf = calculateCmf(prices, period: AppConstants.cmfPeriod);

    final volumeSpike = _isVolumeSpike(prices);
    final vroc = calculateVroc(prices, period: AppConstants.volumeLookbackPeriod);
    final vwap = calculateAnchoredVwap(prices, lookback: AppConstants.anchoredVwapLookback);

    final higherHigh = _isHigherHigh(prices);
    final lowerLow = _isLowerLow(prices);

    final bullishEngulfing = _isBullishEngulfing(prices[prices.length - 2], prices.last);
    final bearishEngulfing = _isBearishEngulfing(prices[prices.length - 2], prices.last);
    final hammer = _isHammer(prices.last);
    final shootingStar = _isShootingStar(prices.last);

    final adxResult = calculateAdx(prices);
    final regimeResult = await _detectRegime(
      adxResult.adxTrending,
      adxResult.adx,
      atr,
      prices.last.close,
      prices,
    );
    final regime = regimeResult.regime;
    final regimeProbs = regimeResult.regimeProbs;

    final swingHighs = _findSwingHighs(prices, lookback: AppConstants.swingPivotLookback);
    final swingLows = _findSwingLows(prices, lookback: AppConstants.swingPivotLookback);

    final recentHighs = swingHighs.length >= 2 ? swingHighs.sublist(swingHighs.length - 2) : swingHighs;
    final recentLows = swingLows.length >= 2 ? swingLows.sublist(swingLows.length - 2) : swingLows;

    final recentHigh = recentHighs.isNotEmpty ? recentHighs.reduce((a, b) => a > b ? a : b) : 0.0;
    final recentLow = recentLows.isNotEmpty ? recentLows.reduce((a, b) => a < b ? a : b) : 0.0;

    final fibLevels = recentHigh > 0 && recentLow > 0
        ? _computeFibonacciLevels(recentHigh, recentLow)
        : <double>[];

    final allSupportLevels = List<double>.from(swingLows);
    final allResistanceLevels = List<double>.from(swingHighs);

    final nearSupport = allSupportLevels.any((level) => _isNearLevel(prices.last.close, level, AppConstants.swingPivotProximityPercent));
    final nearResistance = allResistanceLevels.any((level) => _isNearLevel(prices.last.close, level, AppConstants.swingPivotProximityPercent));
    final nearFib = fibLevels.any((level) => _isNearLevel(prices.last.close, level, AppConstants.fibProximityPercent));

    double? nearestSupport;
    double? nearestResistance;
    double minSupportDist = double.infinity;
    double minResistanceDist = double.infinity;

    for (final level in allSupportLevels) {
      final dist = (prices.last.close - level).abs();
      if (dist < minSupportDist) {
        minSupportDist = dist;
        nearestSupport = level;
      }
    }
    for (final level in allResistanceLevels) {
      final dist = (level - prices.last.close).abs();
      if (dist < minResistanceDist) {
        minResistanceDist = dist;
        nearestResistance = level;
      }
    }

    final distanceToNearestPivot = min(minSupportDist, minResistanceDist);

    final obResult = _detectOrderBlocks(prices);
    final hasBullishOrderBlock = obResult.hasBullishOrderBlock;
    final hasBearishOrderBlock = obResult.hasBearishOrderBlock;
    final bullishOrderBlockPrice = obResult.bullishOrderBlockPrice;
    final bearishOrderBlockPrice = obResult.bearishOrderBlockPrice;

    double trendMultiplier = 0.6 + (regimeProbs[MarketRegime.trending] ?? 0.0) * 0.8;
    double reversionMultiplier = 0.6 + (regimeProbs[MarketRegime.ranging] ?? 0.0) * 0.8;
    if (regime == MarketRegime.crisis) {
      trendMultiplier = 0.3;
      reversionMultiplier = 0.3;
    }

    double buyScore = 0;
    double sellScore = 0;
    double totalWeight = 0;

    void addScore(bool isBullish, double weight) {
      if (isBullish) {
        buyScore += weight;
      } else {
        sellScore += weight;
      }
      totalWeight += weight;
    }

    addScore(ema20 > ema50, 1.0 * trendMultiplier);
    addScore(ema50 > ema200, 1.2 * trendMultiplier);
    if (macdHistogram > 0 && macdLine > macdSignal) {
      addScore(true, 1.2 * trendMultiplier);
    } else if (macdHistogram < 0 && macdLine < macdSignal) {
      addScore(false, 1.2 * trendMultiplier);
    }
    if (adxResult.adxTrending) {
      addScore(adxResult.plusDi > adxResult.minusDi, 1.5 * trendMultiplier);
    }

    if (rsi < AppConstants.rsiOversold) {
      addScore(true, 1.0 * reversionMultiplier);
    } else if (rsi > AppConstants.rsiOverbought) {
      addScore(false, 1.0 * reversionMultiplier);
    }
    if (prices.last.close < bollingerLower) {
      addScore(true, 1.0 * reversionMultiplier);
    } else if (prices.last.close > bollingerUpper) {
      addScore(false, 1.0 * reversionMultiplier);
    }

    addScore(obvRising, 0.8);
    if (cmf > 0) {
      addScore(true, 0.8);
    } else if (cmf < 0) {
      addScore(false, 0.8);
    }

    if (higherHigh) {
      addScore(true, 0.8);
    } else if (lowerLow) {
      addScore(false, 0.8);
    }

    if (bullishEngulfing) {
      addScore(true, 1.0);
    } else if (bearishEngulfing) {
      addScore(false, 1.0);
    }
    if (hammer) {
      addScore(true, 0.8);
    } else if (shootingStar) {
      addScore(false, 0.8);
    }

    SignalType signal;
    double confidence;
    if (buyScore > sellScore) {
      signal = SignalType.buy;
      confidence = (buyScore / totalWeight) * 100;
    } else if (sellScore > buyScore) {
      signal = SignalType.sell;
      confidence = (sellScore / totalWeight) * 100;
    } else {
      signal = SignalType.hold;
      confidence = 50;
    }

    final volatilityRatio = atr / prices.last.close;
    if (volatilityRatio > 0.03) {
      confidence *= 0.9;
    }

    if (signal != SignalType.hold && AppConstants.volumeFilterRequireSpikeOrCmf) {
      if (!volumeSpike && cmf <= AppConstants.volumeFilterCmfThreshold) {
        confidence *= 0.75;
      }
    }

    bool? htfAligned;
    final List<MultiTimeframeConfirmation> multiTfConfirmations = [];
    if (higherTimeframePrices != null && higherTimeframePrices.isNotEmpty) {
      double weightedAlignmentScore = 0;
      double totalWeight = 0;

      for (final entry in higherTimeframePrices.entries) {
        final tf = entry.key;
        final tfPrices = entry.value;
        if (tfPrices.isEmpty) continue;

        final rawConfirmation = _computeMultiTimeframeConfirmation(tfPrices, signal);
        final confirmation = MultiTimeframeConfirmation(
          timeframe: tf,
          trendAligned: rawConfirmation.trendAligned,
          adxAligned: rawConfirmation.adxAligned,
          volumeConfirmed: rawConfirmation.volumeConfirmed,
          obvAligned: rawConfirmation.obvAligned,
          adx: rawConfirmation.adx,
          isTrending: rawConfirmation.isTrending,
          volumeRatio: rawConfirmation.volumeRatio,
        );
        multiTfConfirmations.add(confirmation);

        final weight = AppConstants.higherTimeframeWeights[tf] ?? 1.0;
        final alignmentScore = (confirmation.trendAligned && confirmation.adxAligned && confirmation.volumeConfirmed && confirmation.obvAligned) ? 1.0 : 0.0;
        weightedAlignmentScore += alignmentScore * weight;
        totalWeight += weight;
      }

      if (totalWeight > 0 && signal != SignalType.hold) {
        final avgAlignment = weightedAlignmentScore / totalWeight;
        htfAligned = avgAlignment >= 0.5;
        if (!htfAligned) {
          confidence *= AppConstants.higherTimeframeDisagreementPenalty;
        } else if (avgAlignment > 0.8) {
          confidence *= 1.05;
        }
      }
    }

    final riskLevels = _riskLevels(signal, prices.last.close, atr);

    final probabilities = _calculateProbabilities(
      buyScore: buyScore,
      sellScore: sellScore,
      totalWeight: totalWeight,
      adx: adxResult.adx,
      isTrending: regime == MarketRegime.trending,
    );

final trendScore = calculateTrendScore(prices);

    final mlProbabilities = _mlModelService.predict(prices);

    final ensembleResult = await _computeEnsembleScore(
      signal: signal,
      indicatorConfidence: confidence,
      trendScore: trendScore,
      mlProbabilities: mlProbabilities,
      regimeProbs: regimeProbs,
    );
    confidence = ensembleResult.finalConfidence;
    final ensembleScore = ensembleResult.ensembleScore;

    final filterReasons = <String>[];

    if (regime == MarketRegime.crisis) {
      filterReasons.add('Crisis regime: signals disabled');
      signal = SignalType.hold;
      confidence *= AppConstants.crisisRegimeConfidencePenalty;
    }

    if (signal != SignalType.hold && confidence < AppConstants.minConfidenceThreshold) {
      filterReasons.add('Confidence ${confidence.toStringAsFixed(1)}% below threshold ${AppConstants.minConfidenceThreshold}%');
      signal = SignalType.hold;
      confidence = 50.0;
    }

    if (signal != SignalType.hold && volatilityRatio > AppConstants.volatilityFilterRatio) {
      filterReasons.add('High volatility (${(volatilityRatio * 100).toStringAsFixed(1)}%): signal penalized');
      confidence *= AppConstants.volatilityFilterConfidencePenalty;
    }

    if (AppConstants.timeFilterEnabled) {
      final hour = DateTime.now().hour;
      if (hour >= AppConstants.illiquidHourStart && hour < AppConstants.illiquidHourEnd) {
        filterReasons.add('Illiquid hours (${hour.toString().padLeft(2, '0')}:00 UTC)');
        signal = SignalType.hold;
        confidence = 50.0;
      }
    }

    if (ensembleScore < AppConstants.ensembleMinConfidence) {
      filterReasons.add('Ensemble score ${ensembleScore.toStringAsFixed(1)} below minimum ${AppConstants.ensembleMinConfidence}');
    }

    return Prediction(
      signal: signal,
      confidence: confidence.clamp(0, 100),
      symbol: symbol,
      timestamp: DateTime.now(),
      currentPrice: prices.last.close,
      changePercent: prices.isNotEmpty ? ((prices.last.close - prices.first.open) / prices.first.open * 100) : 0,
      ema20: ema20,
      ema50: ema50,
      ema200: ema200,
      rsi: rsi,
      macdLine: macdLine,
      macdSignal: macdSignal,
      macdHistogram: macdHistogram,
      atr: atr,
      bollingerUpper: bollingerUpper,
      bollingerLower: bollingerLower,
      obv: obv,
      obvRising: obvRising,
      cmf: cmf,
      higherHigh: higherHigh,
      lowerLow: lowerLow,
      bullishEngulfing: bullishEngulfing,
      bearishEngulfing: bearishEngulfing,
      hammer: hammer,
      shootingStar: shootingStar,
      adx: adxResult.adx,
      adxTrending: adxResult.adxTrending,
      adxPlusDi: adxResult.plusDi,
      adxMinusDi: adxResult.minusDi,
      regime: regime,
      regimeProbabilities: regimeProbs,
      stopLoss: riskLevels.stopLoss,
      takeProfit: riskLevels.takeProfit,
      riskRewardRatio: riskLevels.riskReward,
      probabilityUp: probabilities.up,
      probabilityDown: probabilities.down,
      probabilitySideways: probabilities.sideways,
      higherTimeframeAligned: htfAligned,
      multiTimeframeConfirmations: multiTfConfirmations.isEmpty ? null : multiTfConfirmations,
      historicalWinRate: liveWinRate,
      historicalSampleSize: liveSampleSize,
      isNearSupport: nearSupport,
      isNearResistance: nearResistance,
      isNearFibLevel: nearFib,
      distanceToNearestPivot: distanceToNearestPivot,
      supportLevels: allSupportLevels,
      resistanceLevels: allResistanceLevels,
      fibLevels: fibLevels,
      nearestSupport: nearestSupport,
      nearestResistance: nearestResistance,
hasBullishOrderBlock: hasBullishOrderBlock,
        hasBearishOrderBlock: hasBearishOrderBlock,
        bullishOrderBlockPrice: bullishOrderBlockPrice,
        bearishOrderBlockPrice: bearishOrderBlockPrice,
         volumeSpike: volumeSpike,
         vroc: vroc,
         vwap: vwap,
         trendScore: trendScore,
      modelVersion: _mlModelLoaded ? _mlModelService.modelInfo?.version : null,
      modelProbability: _mlModelLoaded
          ? {
              SignalType.buy: mlProbabilities.up.clamp(0, 100) / 100,
              SignalType.sell: mlProbabilities.down.clamp(0, 100) / 100,
              SignalType.hold: mlProbabilities.sideways.clamp(0, 100) / 100,
            }
          : null,
      ensembleScore: ensembleScore,
      finalConfidence: confidence.clamp(0, 100),
      filterReasons: filterReasons,
      );
  }

  ({double up, double down, double sideways}) _calculateProbabilities({
    required double buyScore,
    required double sellScore,
    required double totalWeight,
    required double adx,
    required bool isTrending,
  }) {
    if (totalWeight <= 0) {
      return (up: 33.33, down: 33.33, sideways: 33.34);
    }

    final upRatio = buyScore / totalWeight;
    final downRatio = sellScore / totalWeight;
    final dominance = (upRatio - downRatio).abs();

    final adxSidewaysFactor = adx < 25 ? 0.25 : 0.0;
    final voteBalance = 1.0 - dominance;
    final sidewaysBase = voteBalance * 0.35 + adxSidewaysFactor;

    double upBase = upRatio;
    double downBase = downRatio;
    final directionalTotal = upBase + downBase;
    if (directionalTotal > 0) {
      upBase = upBase / directionalTotal * (1 - sidewaysBase);
      downBase = downBase / directionalTotal * (1 - sidewaysBase);
    }

    final up = upBase * 100;
    final down = downBase * 100;
    final sideways = sidewaysBase * 100;

    final sum = up + down + sideways;
    if (sum <= 0) return (up: 33.33, down: 33.33, sideways: 33.34);

    return (
      up: (up / sum * 100).clamp(0, 100),
      down: (down / sum * 100).clamp(0, 100),
      sideways: (sideways / sum * 100).clamp(0, 100),
    );
  }

  double calculateTrendScore(List<PriceData> prices) {
    final minWindow = max(
      AppConstants.ema200Period,
      max(
        AppConstants.macdSlowPeriod + AppConstants.macdSignalPeriod,
        max(
          AppConstants.adxPeriod + AppConstants.adxSmoothing + 1,
          AppConstants.rsiPeriod + 1,
        ),
      ),
    );

    if (prices.length < minWindow + 10) return 50;

    final lookback = min(prices.length - minWindow - 5, 80);
    if (lookback < 10) return 50;

    final emaRawHistory = <double>[];
    final adxHistory = <double>[];
    final macdSlopeHistory = <double>[];
    final rsiDistHistory = <double>[];
    final momentumHistory = <double>[];

    final startIdx = prices.length - minWindow - lookback;

    for (var i = startIdx; i < prices.length; i++) {
      final slice = prices.sublist(0, i + 1);

      if (slice.length >= AppConstants.ema200Period) {
        final e20 = calculateEma(slice, AppConstants.ema20Period);
        final e50 = calculateEma(slice, AppConstants.ema50Period);
        final e200 = calculateEma(slice, AppConstants.ema200Period);
        final short = e50 > 0 ? (e20 - e50) / e50 : 0;
        final long = e200 > 0 ? (e50 - e200) / e200 : 0;
        emaRawHistory.add((short + long) / 2);
      }

      if (slice.length >= AppConstants.adxPeriod + AppConstants.adxSmoothing + 1) {
        adxHistory.add(calculateAdx(slice).adx);
      }

      if (slice.length >= AppConstants.macdSlowPeriod + AppConstants.macdSignalPeriod + 5) {
        final currHist = calculateMacdLine(slice) - calculateMacdSignal(slice);
        final olderSlice = slice.length > 6 ? slice.sublist(0, slice.length - 5) : slice;
        final olderHist = calculateMacdLine(olderSlice) - calculateMacdSignal(olderSlice);
        macdSlopeHistory.add(currHist - olderHist);
      }

      if (slice.length >= AppConstants.rsiPeriod + 1) {
        rsiDistHistory.add((calculateRsi(slice, period: AppConstants.rsiPeriod) - 50).abs());
      }

      if (slice.length >= AppConstants.atrPeriod + 11) {
        final atr = calculateAtr(slice);
        if (atr > 0) {
          momentumHistory.add((slice.last.close - slice[slice.length - 11].close) / atr);
        }
      }
    }

    final currEma20 = calculateEma(prices, AppConstants.ema20Period);
    final currEma50 = calculateEma(prices, AppConstants.ema50Period);
    final currEma200 = calculateEma(prices, AppConstants.ema200Period);
    final currAdx = calculateAdx(prices).adx;
    final currRsi = calculateRsi(prices, period: AppConstants.rsiPeriod);
    final currAtr = calculateAtr(prices);

    final currEmaShort = currEma50 > 0 ? (currEma20 - currEma50) / currEma50 : 0;
    final currEmaLong = currEma200 > 0 ? (currEma50 - currEma200) / currEma200 : 0;
    final currEmaRaw = (currEmaShort + currEmaLong) / 2;

    final currMacdHist = calculateMacdLine(prices) - calculateMacdSignal(prices);
    final olderSlice = prices.length > 6 ? prices.sublist(0, prices.length - 5) : prices;
    final olderMacdHist = calculateMacdLine(olderSlice) - calculateMacdSignal(olderSlice);
    final currMacdSlope = currMacdHist - olderMacdHist;

    final currRsiDist = (currRsi - 50).abs();
    final currMomentum = currAtr > 0 && prices.length > 10
        ? (prices.last.close - prices[prices.length - 11].close) / currAtr
        : 0.0;

    final emaScore = _normalize(currEmaRaw, emaRawHistory);
    final adxScore = _normalize(currAdx, adxHistory);
    final macdScore = _normalize(currMacdSlope, macdSlopeHistory);
    final rsiScore = _normalize(currRsiDist, rsiDistHistory);
    final momentumScore = _normalize(currMomentum, momentumHistory);

    final trendScore = (emaScore * 0.25 +
                        adxScore * 0.25 +
                        macdScore * 0.25 +
                        rsiScore * 0.15 +
                        momentumScore * 0.10)
        .clamp(0.0, 100.0);

    return trendScore;
  }

  double _normalize(double value, List<double> history) {
    if (history.isEmpty) return 50;
    final minVal = history.reduce(min).toDouble();
    final maxVal = history.reduce(max).toDouble();
    if (maxVal == minVal) return 50;
    return ((value - minVal) / (maxVal - minVal) * 100).clamp(0.0, 100.0);
  }

  Prediction _emptyPrediction(String symbol, List<PriceData> prices) {
    return Prediction(
      signal: SignalType.hold,
      confidence: 0,
      symbol: symbol,
      timestamp: DateTime.now(),
      currentPrice: prices.isNotEmpty ? prices.last.close : 0,
      changePercent: 0,
      ema20: 0,
      ema50: 0,
      ema200: 0,
      rsi: 50,
      macdLine: 0,
      macdSignal: 0,
      macdHistogram: 0,
      atr: 0,
      bollingerUpper: 0,
      bollingerLower: 0,
      obv: 0,
      obvRising: false,
      cmf: 0,
      higherHigh: false,
      lowerLow: false,
      bullishEngulfing: false,
      bearishEngulfing: false,
      hammer: false,
      shootingStar: false,
      adx: 0,
      adxTrending: false,
      adxPlusDi: 0,
      adxMinusDi: 0,
      regime: MarketRegime.unknown,
      regimeProbabilities: {
        MarketRegime.trending: 0.0,
        MarketRegime.ranging: 0.0,
        MarketRegime.crisis: 0.0,
        MarketRegime.unknown: 1.0,
      },
      stopLoss: 0,
      takeProfit: 0,
      riskRewardRatio: 0,
      probabilityUp: 33.33,
      probabilityDown: 33.33,
      probabilitySideways: 33.34,
      isNearSupport: false,
      isNearResistance: false,
      isNearFibLevel: false,
      distanceToNearestPivot: 0,
      supportLevels: const [],
      resistanceLevels: const [],
      fibLevels: const [],
      nearestSupport: null,
      nearestResistance: null,
hasBullishOrderBlock: null,
       hasBearishOrderBlock: null,
       bullishOrderBlockPrice: null,
       bearishOrderBlockPrice: null,
volumeSpike: false,
          vroc: null,
          vwap: null,
          trendScore: 50,
modelVersion: null,
       modelProbability: null,
ensembleScore: 50.0,
finalConfidence: 50.0,
filterReasons: const [],
       );
    }

   Future<({double ensembleScore, double finalConfidence})> _computeEnsembleScore({
      required SignalType signal,
      required double indicatorConfidence,
      required double trendScore,
      required ({double up, double down, double sideways}) mlProbabilities,
      required Map<MarketRegime, double>? regimeProbs,
    }) async {
      final indicatorScore = indicatorConfidence.clamp(0.0, 100.0);

      final mlUp = mlProbabilities.up.clamp(0.0, 100.0);
      final mlDown = mlProbabilities.down.clamp(0.0, 100.0);
      double mlScore;
      if (signal == SignalType.buy) {
        mlScore = mlUp;
      } else if (signal == SignalType.sell) {
        mlScore = mlDown;
      } else {
        mlScore = 100.0 - (mlUp + mlDown).clamp(0.0, 100.0);
      }

      final regimeTrending = (regimeProbs?[MarketRegime.trending] ?? 0.0).clamp(0.0, 1.0);
      final regimeRanging = (regimeProbs?[MarketRegime.ranging] ?? 0.0).clamp(0.0, 1.0);
      final regimeCrisis = (regimeProbs?[MarketRegime.crisis] ?? 0.0).clamp(0.0, 1.0);
      double regimeScore;
      if (signal == SignalType.buy || signal == SignalType.sell) {
        regimeScore = regimeTrending * 100.0;
        if (regimeCrisis > 0.5) {
          regimeScore *= 0.5;
        }
      } else {
        regimeScore = regimeRanging * 100.0;
      }
      regimeScore = regimeScore.clamp(0.0, 100.0);

      final wIndicator = AppConstants.ensembleWeightIndicator;
      final wMl = AppConstants.ensembleWeightMl;
      final wRegime = AppConstants.ensembleWeightRegime;
      final totalWeight = wIndicator + wMl + wRegime;

      final weightedEnsembleScore = ((indicatorScore * wIndicator + mlScore * wMl + regimeScore * wRegime) / totalWeight).clamp(0.0, 100.0);

      double ensembleScore;
      try {
        ensembleScore = await _metaLearnerService.predictConfidence(
          indicatorConfidence: indicatorScore,
          mlProbUp: mlUp,
          mlProbDown: mlDown,
          mlProbSideways: mlProbabilities.sideways,
          regimeProbs: regimeProbs,
        );
      } catch (_) {
        ensembleScore = weightedEnsembleScore;
      }

      double finalConfidence;
      if (signal == SignalType.hold) {
        finalConfidence = ensembleScore;
      } else if (ensembleScore > AppConstants.ensembleScoreBoostThreshold) {
        finalConfidence = indicatorConfidence * AppConstants.ensembleBoostFactor;
      } else if (ensembleScore < AppConstants.ensembleScorePenaltyThreshold) {
        finalConfidence = indicatorConfidence * AppConstants.ensemblePenaltyFactor;
      } else {
        finalConfidence = indicatorConfidence;
      }
      finalConfidence = finalConfidence.clamp(0.0, 100.0);

      return (ensembleScore: ensembleScore, finalConfidence: finalConfidence);
    }
  }
