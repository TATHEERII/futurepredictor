import 'package:flutter/material.dart';
import '../providers/app_provider.dart';

class SymbolSelectorWidget extends StatelessWidget {
  final AppProvider provider;

  const SymbolSelectorWidget({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.timeline, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: provider.selectedSymbol,
                items: provider.availableSymbols
                    .map((symbol) => DropdownMenuItem(
                          value: symbol,
                          child: Text(symbol),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    provider.setSymbol(value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}