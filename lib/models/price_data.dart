class PriceData {
  final DateTime timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  PriceData({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory PriceData.fromJson(List<dynamic> json) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.parse(v);
      return double.parse(v.toString());
    }

    return PriceData(
      timestamp: DateTime.fromMillisecondsSinceEpoch(json[0] as int),
      open: toDouble(json[1]),
      high: toDouble(json[2]),
      low: toDouble(json[3]),
      close: toDouble(json[4]),
      volume: toDouble(json[5]),
    );
  }
}