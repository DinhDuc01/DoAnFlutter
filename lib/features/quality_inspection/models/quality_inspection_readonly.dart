class QualityInspectionReadOnly {
  const QualityInspectionReadOnly({
    this.inspectionId,
    this.paddyLotId,
    this.lotCode,
    this.lotStatusCode,
    this.inspectorId,
    this.inspectorName,
    this.inspectedAt,
    this.moisturePercent,
    this.impurityPercent,
    this.moldLevel,
    this.pestLevel,
    this.packagingStatus,
    this.passedInspection,
    this.handling,
    this.note,
    this.affectedWeightKg,
    this.createdDate,
    this.lastModifiedDate,
  });

  final int? inspectionId;
  final int? paddyLotId;
  final String? lotCode;
  final String? lotStatusCode;
  final int? inspectorId;
  final String? inspectorName;
  final DateTime? inspectedAt;
  final double? moisturePercent;
  final double? impurityPercent;
  final String? moldLevel;
  final String? pestLevel;
  final String? packagingStatus;
  final bool? passedInspection;
  final String? handling;
  final String? note;
  final double? affectedWeightKg;
  final DateTime? createdDate;
  final DateTime? lastModifiedDate;
}

class QualityInspectionPage {
  const QualityInspectionPage({
    required this.items,
    required this.recordsTotal,
    required this.recordsFiltered,
  });
  final List<QualityInspectionReadOnly> items;
  final int recordsTotal;
  final int recordsFiltered;
}

class QualityLotSummary {
  const QualityLotSummary({this.values = const {}});
  final Map<String, dynamic> values;
  String? text(String key) => values[key]?.toString();
}
