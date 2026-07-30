enum MlModelType { xgboost, lightgbm, ruleBased }

class MlModelInfo {
  final String version;
  final MlModelType type;
  final DateTime trainedAt;
  final Map<String, double> metrics;
  final List<String> featureNames;
  final int treeCount;
  final double baseScore;

  MlModelInfo({
    required this.version,
    required this.type,
    required this.trainedAt,
    required this.metrics,
    required this.featureNames,
    required this.treeCount,
    this.baseScore = 0.5,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'type': type.name,
        'trainedAt': trainedAt.toIso8601String(),
        'metrics': metrics,
        'featureNames': featureNames,
        'treeCount': treeCount,
        'baseScore': baseScore,
      };

  factory MlModelInfo.fromJson(Map<String, dynamic> json) => MlModelInfo(
        version: json['version'] as String,
        type: MlModelType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => MlModelType.ruleBased,
        ),
        trainedAt: DateTime.parse(json['trainedAt'] as String),
        metrics: Map<String, double>.from(
            json['metrics'] as Map<String, dynamic>),
        featureNames: List<String>.from(json['featureNames'] as List),
        treeCount: json['treeCount'] as int,
        baseScore: (json['baseScore'] as num).toDouble(),
      );
}