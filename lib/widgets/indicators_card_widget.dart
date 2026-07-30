import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../utils/helpers.dart';

class IndicatorsCardWidget extends StatelessWidget {
  final Prediction prediction;

  const IndicatorsCardWidget({super.key, required this.prediction});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indicators',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _indicatorRow('EMA (20 / 50 / 200)',
                '${prediction.ema20.toStringAsFixed(2)} / ${prediction.ema50.toStringAsFixed(2)} / ${prediction.ema200.toStringAsFixed(2)}'),
            _indicatorRow('RSI', prediction.rsi.toStringAsFixed(1)),
            _indicatorRow('MACD Histogram', prediction.macdHistogram.toStringAsFixed(2)),
            _indicatorRow('Bollinger',
                '${prediction.bollingerLower.toStringAsFixed(2)} / ${prediction.bollingerUpper.toStringAsFixed(2)}'),
            _indicatorRow('ADX', prediction.adx.toStringAsFixed(1)),
            _indicatorRow('ATR', formatCurrency(prediction.atr)),
            _indicatorRow('Trend Score', prediction.trendScore.toStringAsFixed(1)),
            const SizedBox(height: 8),
            const Text(
              'Volume',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
_indicatorRow('OBV Rising', prediction.obvRising ? 'Yes' : 'No'),
                _indicatorRow('CMF', prediction.cmf.toStringAsFixed(3)),
                _indicatorRow('VROC', prediction.vroc != null ? '${prediction.vroc!.toStringAsFixed(1)}%' : 'N/A'),
                _indicatorRow('Volume Spike', prediction.volumeSpike ? 'Yes' : 'No'),
                _indicatorRow('VWAP', prediction.vwap != null ? prediction.vwap!.toStringAsFixed(2) : 'N/A'),
            const SizedBox(height: 8),
            const Text(
              'Market Structure',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            _indicatorRow('Higher High', prediction.higherHigh ? 'Yes' : 'No'),
            _indicatorRow('Lower Low', prediction.lowerLow ? 'Yes' : 'No'),
            const SizedBox(height: 8),
            const Text(
              'Price Action',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            _indicatorRow('Bullish Engulfing', prediction.bullishEngulfing ? 'Yes' : 'No'),
            _indicatorRow('Bearish Engulfing', prediction.bearishEngulfing ? 'Yes' : 'No'),
            _indicatorRow('Hammer', prediction.hammer ? 'Yes' : 'No'),
            _indicatorRow('Shooting Star', prediction.shootingStar ? 'Yes' : 'No'),
            const SizedBox(height: 8),
            const Text(
              'Probabilities',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            _indicatorRow('Probability Up', '${prediction.probabilityUp.toStringAsFixed(1)}%'),
            _indicatorRow('Probability Down', '${prediction.probabilityDown.toStringAsFixed(1)}%'),
            _indicatorRow('Probability Sideways', '${prediction.probabilitySideways.toStringAsFixed(1)}%'),
            if (prediction.supportLevels.isNotEmpty || prediction.resistanceLevels.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Support & Resistance',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              _indicatorRow('Near Support', prediction.isNearSupport ? 'Yes' : 'No'),
              _indicatorRow('Near Resistance', prediction.isNearResistance ? 'Yes' : 'No'),
              _indicatorRow('Nearest Support', prediction.nearestSupport != null ? prediction.nearestSupport!.toStringAsFixed(2) : 'N/A'),
              _indicatorRow('Nearest Resistance', prediction.nearestResistance != null ? prediction.nearestResistance!.toStringAsFixed(2) : 'N/A'),
              _indicatorRow('Support Levels', prediction.supportLevels.isEmpty ? 'N/A' : prediction.supportLevels.map((l) => l.toStringAsFixed(2)).join(', ')),
              _indicatorRow('Resistance Levels', prediction.resistanceLevels.isEmpty ? 'N/A' : prediction.resistanceLevels.map((l) => l.toStringAsFixed(2)).join(', ')),
            ],
            if (prediction.fibLevels.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Fibonacci Levels',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              _indicatorRow('Near Fib Level', prediction.isNearFibLevel ? 'Yes' : 'No'),
              _indicatorRow('Fib Levels', prediction.fibLevels.map((l) => l.toStringAsFixed(2)).join(', ')),
            ],
            if (prediction.hasBullishOrderBlock != null || prediction.hasBearishOrderBlock != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Order Blocks',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              _indicatorRow('Bullish OB', prediction.hasBullishOrderBlock == true ? (prediction.bullishOrderBlockPrice?.toStringAsFixed(2) ?? 'Yes') : 'No'),
              _indicatorRow('Bearish OB', prediction.hasBearishOrderBlock == true ? (prediction.bearishOrderBlockPrice?.toStringAsFixed(2) ?? 'Yes') : 'No'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _indicatorRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
