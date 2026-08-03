class QualityInspection {
  const QualityInspection({
    required this.id,
    required this.paddyLotId,
    required this.lotCode,
    required this.inspectedAt,
    required this.passed,
    this.inspectorName,
    this.moisturePercent,
    this.impurityPercent,
    this.moldLevel,
    this.pestLevel,
    this.packagingStatus,
    this.handling,
    this.note,
  });

  final int id;
  final int paddyLotId;
  final String lotCode;
  final String? inspectorName;
  final DateTime inspectedAt;
  final double? moisturePercent;
  final double? impurityPercent;
  final String? moldLevel;
  final String? pestLevel;
  final String? packagingStatus;
  final bool passed;
  final String? handling;
  final String? note;
}
