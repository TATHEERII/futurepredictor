import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../utils/helpers.dart';

class SignalCardWidget extends StatelessWidget {
  final Prediction prediction;

  const SignalCardWidget({super.key, required this.prediction});

  Color _getSignalColor() {
    switch (prediction.signal) {
      case SignalType.buy:
        return const Color(0xFF00E676);
      case SignalType.sell:
        return const Color(0xFFFF1744);
      case SignalType.hold:
        return const Color(0xFFFFC107);
    }
  }

  IconData _getSignalIcon() {
    switch (prediction.signal) {
      case SignalType.buy:
        return Icons.trending_up;
      case SignalType.sell:
        return Icons.trending_down;
      case SignalType.hold:
        return Icons.horizontal_rule;
    }
  }

  @override
Widget build(BuildContext context) {
     return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getSignalIcon(), color: _getSignalColor(), size: 32),
                const SizedBox(width: 8),
                Text(
                  prediction.signalLabel,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _getSignalColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                _regimeChip(),
                if (prediction.higherTimeframeAligned != null) _htfChip(),
                if (prediction.regimeProbabilities != null) ..._regimeProbChips(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              prediction.symbol,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('Price', formatCurrency(prediction.currentPrice)),
                _buildMetric('RSI', prediction.rsi.toStringAsFixed(1)),
                _buildMetric(
                  'Prob Up',
                  '${prediction.probabilityUp.toStringAsFixed(1)}%',
                  color: Colors.green[700],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  'Prob Down',
                  '${prediction.probabilityDown.toStringAsFixed(1)}%',
                  color: Colors.red[700],
                ),
                _buildMetric(
                  'Sideways',
                  '${prediction.probabilitySideways.toStringAsFixed(1)}%',
                  color: Colors.orange[700],
                ),
                _buildMetric(
                  'MACD',
                  prediction.macdHistogram.toStringAsFixed(2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  'ATR',
                  formatCurrency(prediction.atr),
                ),
                _buildMetric(
                  'ADX',
                  prediction.adx.toStringAsFixed(1),
                ),
                _buildMetric(
                  'EMA',
                  '${prediction.ema20.toStringAsFixed(0)} / ${prediction.ema50.toStringAsFixed(0)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  'EMA200',
                  prediction.ema200.toStringAsFixed(0),
                ),
                _buildMetric(
                  'Bollinger',
                  prediction.bollingerStatus,
                ),
                _buildMetric(
                  'OBV',
                  prediction.obvRising ? 'Rising' : 'Falling',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  'CMF',
                  prediction.cmf.toStringAsFixed(3),
                ),
                _buildMetric(
                  'Structure',
                  prediction.higherHigh
                      ? 'Higher High'
                      : prediction.lowerLow
                          ? 'Lower Low'
                          : 'Flat',
                ),
              ],
            ),
            if (prediction.signal != SignalType.hold && prediction.stopLoss > 0) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              const Text(
                'Suggested Risk Levels (ATR-based, not advice)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric('Stop Loss', formatCurrency(prediction.stopLoss), color: Colors.red[700]),
                  _buildMetric('Take Profit', formatCurrency(prediction.takeProfit), color: Colors.green[700]),
                  _buildMetric('R:R', '${prediction.riskRewardRatio.toStringAsFixed(2)}:1'),
                ],
              ),
            ],
            if (prediction.modelProbability != null) ...[
              const SizedBox(height: 8),
              _buildMetric(
                'ML Prob Up',
                '${((prediction.modelProbability?[SignalType.buy] ?? 0) * 100).toStringAsFixed(1)}%',
                color: Colors.green[700],
              ),
              _buildMetric(
                'ML Prob Down',
                '${((prediction.modelProbability?[SignalType.sell] ?? 0) * 100).toStringAsFixed(1)}%',
                color: Colors.red[700],
              ),
            ],
const SizedBox(height: 8),
              _buildMetric(
                'Ensemble Score',
                prediction.ensembleScore.toStringAsFixed(1),
                color: prediction.ensembleScore > 60 ? Colors.green[700] : prediction.ensembleScore < 40 ? Colors.red[700] : Colors.blue[700],
              ),
              if (prediction.filterReasons.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Filter Reasons',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange[700]),
                ),
                ...prediction.filterReasons.map((reason) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        children: [
                          Icon(Icons.filter_list, size: 12, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: prediction.finalConfidence / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(_getSignalColor()),
                minHeight: 8,
              ),
          ],
        ),
      ),
    );
  }

  Widget _regimeChip() {
    final color = prediction.regime == MarketRegime.trending
        ? Colors.blue
        : prediction.regime == MarketRegime.ranging
            ? Colors.orange
            : prediction.regime == MarketRegime.crisis
                ? Colors.red
                : Colors.grey;
    return Chip(
      label: Text(prediction.regimeLabel, style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  List<Widget> _regimeProbChips() {
    final probs = prediction.regimeProbabilities;
    if (probs == null) return [];
    return [
      _buildProbChip('Trend', probs[MarketRegime.trending] ?? 0.0, Colors.blue),
      _buildProbChip('Range', probs[MarketRegime.ranging] ?? 0.0, Colors.orange),
      if ((probs[MarketRegime.crisis] ?? 0.0) > 0.01)
        _buildProbChip('Crisis', probs[MarketRegime.crisis] ?? 0.0, Colors.red),
    ];
  }

  Widget _buildProbChip(String label, double value, Color color) {
    return Chip(
      label: Text('$label ${(value * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 10, color: Colors.white)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _htfChip() {
    final aligned = prediction.higherTimeframeAligned!;
    return Chip(
      label: Text(
        aligned ? '4h trend agrees' : '4h trend disagrees',
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
      backgroundColor: aligned ? Colors.green[700] : Colors.red[700],
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildMetric(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
