import 'package:flutter/material.dart';
import '../models/price_data.dart';
import '../utils/helpers.dart';

class PriceChartWidget extends StatelessWidget {
  final List<PriceData> priceData;
  final double? ema20;
  final double? ema50;
  final double? ema200;
  final double? rsiValue;

  const PriceChartWidget({
    super.key,
    required this.priceData,
    this.ema20,
    this.ema50,
    this.ema200,
    this.rsiValue,
  });

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
              'Price Chart',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: priceData.length,
                itemBuilder: (context, index) {
                  final candle = priceData[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: SizedBox(
                      width: 8,
                      height: 100,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: candle.close >= candle.open
                              ? Colors.green
                              : Colors.red,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (ema20 != null && ema20! > 0)
              _legendRow('EMA20', Colors.cyan),
            if (ema50 != null && ema50! > 0)
              _legendRow('EMA50', Colors.orange),
            if (ema200 != null && ema200! > 0)
              _legendRow('EMA200', Colors.purple),
            if (rsiValue != null)
              _legendRow('RSI', rsiValue! > 70 ? Colors.red : rsiValue! < 30 ? Colors.green : Colors.grey),
            const SizedBox(height: 8),
            Text(
              'Latest: ${formatCurrency(priceData.last.close)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
