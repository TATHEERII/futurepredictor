import 'package:flutter/material.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';

class BotControlsWidget extends StatelessWidget {
  final AppProvider provider;

  const BotControlsWidget({super.key, required this.provider});

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
              'Bot Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.isRunning ? null : provider.fetchData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Fetch'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.isRunning ? provider.stopBot : provider.startBot,
                    icon: Icon(
                      provider.isRunning ? Icons.stop : Icons.play_arrow,
                    ),
                    label: Text(provider.isRunning ? 'Stop' : 'Start'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Timeframe',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<String>(
                        value: provider.backtestInterval,
                        isExpanded: true,
                        items: AppConstants.backtestIntervals.map((interval) {
                          return DropdownMenuItem(
                            value: interval,
                            child: Text(interval),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            provider.setBacktestInterval(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Candle Count',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<int>(
                        value: provider.backtestCandleLimit,
                        isExpanded: true,
                        items: const [100, 200, 500, 1000].map((count) {
                          return DropdownMenuItem(
                            value: count,
                            child: Text('$count'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            provider.setBacktestCandleLimit(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Holding Period',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<int>(
                        value: provider.backtestHoldingPeriod,
                        isExpanded: true,
                        items: AppConstants.backtestHoldingPeriodOptions.map((period) {
                          return DropdownMenuItem(
                            value: period,
                            child: Text('$period candles'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            provider.setBacktestHoldingPeriod(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set Count',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<int>(
                        value: provider.backtestSetCount,
                        isExpanded: true,
                        items: AppConstants.backtestSetCountOptions.map((count) {
                          return DropdownMenuItem(
                            value: count,
                            child: Text('$count'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            provider.setBacktestSetCount(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Candles Per Set',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<int>(
                        value: provider.backtestCandlesPerSet,
                        isExpanded: true,
                        items: AppConstants.backtestCandlesPerSetOptions.map((count) {
                          return DropdownMenuItem(
                            value: count,
                            child: Text('$count'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            provider.setBacktestCandlesPerSet(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: provider.isBacktesting ? null : provider.runBacktest,
                icon: provider.isBacktesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics_outlined),
                label: Text(provider.isBacktesting ? 'Running Backtest…' : 'Run Backtest'),
              ),
            ),
            const SizedBox(height: 12),
            if (provider.isRunning)
              Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Bot is running',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
