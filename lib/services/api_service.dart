import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/price_data.dart';
import '../utils/constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message${statusCode != null ? ' (status $statusCode)' : ''}';
}

class ApiService {
  final http.Client _client;
  final int maxRetries;
  final Duration requestTimeout;

  ApiService({
    http.Client? client,
    this.maxRetries = 3,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  Future<http.Response> _getWithRetry(Uri url) async {
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _client.get(url, headers: {'Content-Type': 'application/json'}).timeout(requestTimeout);

        // Retry on server errors and rate limiting; fail fast on 4xx (except 429).
        if (response.statusCode == 200) return response;
        if (response.statusCode == 429 || response.statusCode >= 500) {
          lastError = ApiException('Server error', statusCode: response.statusCode);
        } else {
          throw ApiException('Request failed', statusCode: response.statusCode);
        }
      } on TimeoutException {
        lastError = ApiException('Request timed out');
      } on ApiException {
        rethrow;
      } catch (e) {
        lastError = e;
      }

      if (attempt < maxRetries) {
        // Exponential backoff with jitter: 300ms, 600ms, 1200ms...
        final backoffMs = (300 * pow(2, attempt)).toInt() + Random().nextInt(150);
        await Future.delayed(Duration(milliseconds: backoffMs));
      }
    }
    throw ApiException('Failed after ${maxRetries + 1} attempts: $lastError');
  }

  Future<List<PriceData>> fetchKlines(
    String symbol, {
    int? limit,
    String? interval,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}${AppConstants.klinesEndpoint}').replace(
      queryParameters: {
        'symbol': symbol,
        'interval': interval ?? AppConstants.klineInterval,
        'limit': (limit ?? AppConstants.klineLimit).toString(),
      },
    );

    final response = await _getWithRetry(url);

    try {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => PriceData.fromJson(item)).toList();
    } catch (e) {
      throw ApiException('Failed to parse kline data: $e');
    }
  }

  /// Fetches candles on a higher timeframe (default 4h) for multi-timeframe
  /// trend confirmation, so the app isn't only ever looking at one
  /// resolution when deciding a signal's direction.
  Future<List<PriceData>> fetchHigherTimeframeKlines(String symbol, {String? interval}) {
    return fetchKlines(
      symbol,
      interval: interval ?? AppConstants.higherTimeframeInterval,
      limit: AppConstants.higherTimeframeLimit,
    );
  }

  Future<Map<String, List<PriceData>>> fetchAllHigherTimeframes(String symbol) async {
    final results = <String, List<PriceData>>{};
    for (final tf in AppConstants.higherTimeframes) {
      try {
        final data = await fetchHigherTimeframeKlines(symbol, interval: tf);
        results[tf] = data;
      } catch (_) {
        results[tf] = [];
      }
    }
    return results;
  }

  Future<Map<String, dynamic>> fetchSymbolInfo(String symbol) async {
    final url = Uri.parse('${AppConstants.baseUrl}${AppConstants.symbolEndpoint}');

    final response = await _getWithRetry(url);

    final data = json.decode(response.body);
    final symbols = data['symbols'] as List<dynamic>;

    // Previously this used firstWhere(orElse: () => {}), which silently
    // returned an empty map for typos or delisted symbols instead of
    // surfacing an error. Now callers get an explicit exception.
    final match = symbols.cast<Map<String, dynamic>>().firstWhere(
          (s) => s['symbol'] == symbol,
          orElse: () => throw ApiException('Symbol "$symbol" not found on exchange'),
        );

    return Map<String, dynamic>.from(match);
  }

  void dispose() {
    _client.close();
  }
}
