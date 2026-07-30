import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'providers/app_provider.dart';

class CryptoFuturesApp extends StatelessWidget {
  const CryptoFuturesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crypto Futures Predictor',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const HomeScreen(),
      ),
    );
  }
}