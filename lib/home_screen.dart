import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prediction.dart';
import '../providers/app_provider.dart';
import '../utils/helpers.dart';
import '../widgets/backtest_results_widget.dart';
import '../widgets/bot_controls_widget.dart';
import '../widgets/indicators_card_widget.dart';
import '../widgets/price_chart_widget.dart';
import '../widgets/signal_card_widget.dart';
import '../widgets/symbol_selector_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto Futures Predictor'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.priceData.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SymbolSelectorWidget(provider: provider),
                const SizedBox(height: 16),
                BotControlsWidget(provider: provider),
                const SizedBox(height: 16),
                if (provider.errorMessage.isNotEmpty)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              provider.errorMessage,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (provider.backtestResult != null) ...[
                  BacktestResultsWidget(result: provider.backtestResult!),
                  const SizedBox(height: 16),
                ],
                if (provider.currentPrediction != null)
                  SignalCardWidget(
                    prediction: provider.currentPrediction!,
                  ),
                if (provider.currentPrediction != null)
                  const SizedBox(height: 16),
                if (provider.currentPrediction != null)
                  IndicatorsCardWidget(
                    prediction: provider.currentPrediction!,
                  ),
                const SizedBox(height: 16),
                if (provider.priceData.isNotEmpty)
                  PriceChartWidget(
                    priceData: provider.priceData,
                    ema20: provider.currentPrediction?.ema20,
                    ema50: provider.currentPrediction?.ema50,
                    ema200: provider.currentPrediction?.ema200,
                    rsiValue: provider.currentPrediction?.rsi,
                  ),
                const SizedBox(height: 16),
                if (provider.predictionHistory.length > 1) ...[
                  const Text(
                    'Prediction History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...provider.predictionHistory.take(20).map((pred) {
                    final color = pred.signal == SignalType.buy
                        ? Colors.green[700]
                        : pred.signal == SignalType.sell
                            ? Colors.red[700]
                            : Colors.amber[700];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        pred.signal == SignalType.buy
                            ? Icons.arrow_upward
                            : pred.signal == SignalType.sell
                                ? Icons.arrow_downward
                                : Icons.horizontal_rule,
                        color: color,
                      ),
                      title: Text(pred.symbol),
                      subtitle: Text(
                        '${pred.signalLabel} | Confidence: ${pred.confidence.toStringAsFixed(1)}% | ${pred.regimeLabel}',
                      ),
                      trailing: Text(
                        formatCurrency(pred.currentPrice),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
