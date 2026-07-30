import 'package:flutter/material.dart';
import '../models/backtest_result.dart';
import '../utils/helpers.dart';

class BacktestResultsWidget extends StatelessWidget {
  final BacktestResult result;

  const BacktestResultsWidget({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final verdictColor = result.beatsBuyAndHold ? Colors.green[700] : Colors.red[700];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Backtest Results',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(
                  result.beatsBuyAndHold ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: verdictColor,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              result.beatsBuyAndHold
                  ? 'Strategy outperformed buy-and-hold over this window'
                  : 'Strategy underperformed buy-and-hold over this window',
              style: TextStyle(fontSize: 12, color: verdictColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _statRow('Total signals', '${result.totalSignals}  (${result.buySignals} buy / ${result.sellSignals} sell)'),
            _statRow('Win rate', '${result.winRate.toStringAsFixed(1)}%  (${result.wins}W / ${result.losses}L)'),
            _statRow('Avg return / trade', formatPercent(result.averageReturnPercent)),
            _statRow('Total return (compounded)', formatPercent(result.totalReturnPercent)),
            _statRow('Buy & hold return', formatPercent(result.buyAndHoldReturnPercent)),
            _statRow('Max drawdown', formatPercent(-result.maxDrawdownPercent.abs())),
            _statRow('Return/volatility ratio', result.sharpeLikeRatio.toStringAsFixed(2)),
            const SizedBox(height: 8),
            Text(
              'Simulated on historical candles, using only data available at each point in time '
              '(no lookahead). Past performance on historical data does not guarantee future results.',
              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
