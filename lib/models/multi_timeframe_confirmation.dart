class MultiTimeframeConfirmation {
  final String timeframe;
  final bool trendAligned;
  final bool adxAligned;
  final bool volumeConfirmed;
  final bool obvAligned;
  final double adx;
  final bool isTrending;
  final double volumeRatio;

  MultiTimeframeConfirmation({
    required this.timeframe,
    required this.trendAligned,
    required this.adxAligned,
    required this.volumeConfirmed,
    required this.obvAligned,
    required this.adx,
    required this.isTrending,
    required this.volumeRatio,
  });
}
