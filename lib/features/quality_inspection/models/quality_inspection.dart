import '../../../core/api/json_reader.dart';
import '../../../core/utils/format.dart';

/// Model màn "Chất lượng & cách ly" — khớp DTO backend và bản web.
///
/// Mobile KHÔNG tạo phiếu kiểm định: phiếu nháp do backend tự sinh khi phiếu
/// mua lúa được duyệt (lô ở trạng thái `AWAITING_QC`). Mobile chỉ CẬP NHẬT
/// phiếu theo đúng logic web — chọn bao tách cách ly, tự gắn người kiểm định là
/// người đang sửa phiếu, backend tự sinh phiếu nhập kho sau khi có kết quả.

/// Mức độ rủi ro suy diễn từ chỉ số kiểm định (cột "MỨC ĐỘ" của web).
enum QualitySeverity {
  pending('Chờ kiểm định'),
  low('Thấp'),
  medium('Trung bình'),
  high('Cao');

  const QualitySeverity(this.label);

  final String label;
}

/// Một phiếu kiểm định (dùng chung cho dòng bảng, chi tiết và lịch sử).
class QualityInspection {
  const QualityInspection({
    required this.id,
    required this.paddyLotId,
    this.lotCode,
    this.lotStatusCode,
    this.inspectionType,
    this.completedAt,
    this.completedBy,
    this.targetedBagCount,
    this.targetedWeightKg,
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

  final int id;
  final int paddyLotId;
  final String? lotCode;

  /// Code trạng thái lô — `AWAITING_QC` nghĩa là phiếu nháp, chờ nhập kết quả.
  final String? lotStatusCode;
  final String? inspectionType;
  final DateTime? completedAt;
  final int? completedBy;
  final int? targetedBagCount;
  final double? targetedWeightKg;
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

  String get lotLabel => (lotCode == null || lotCode!.trim().isEmpty)
      ? 'Lô #$paddyLotId'
      : lotCode!;

  /// Phiếu nháp (chờ nhập kết quả) — lô đang ở trạng thái AWAITING_QC.
  bool get isSession => (inspectionType ?? '').trim().isNotEmpty;

  /// Phiên mới dùng `completedAt`; chỉ dữ liệu legacy mới fallback trạng thái lô.
  bool get isDraft => isSession
      ? completedAt == null
      : (lotStatusCode ?? '').toUpperCase() == 'AWAITING_QC';

  bool get isCompletedSession => isSession && completedAt != null;

  /// Phiếu đã tách lô cách ly — backend khóa sửa lô/kết quả/kg và cấm xóa.
  bool get wasSplit => passedInspection == false && (affectedWeightKg ?? 0) > 0;

  String get statusText {
    if (isDraft) return 'Chờ kiểm định';
    return passedInspection == true ? 'Đạt' : 'Cách ly';
  }

  /// Phạm vi xử lý: Tách một phần / Toàn bộ lô / —.
  String get scopeText {
    if (passedInspection == true) return '—';
    return (affectedWeightKg ?? 0) > 0 ? 'Tách một phần' : 'Toàn bộ lô';
  }

  /// Rủi ro chính suy diễn từ chỉ số kiểm định (giống `riskText` của web).
  String get riskText {
    final parts = <String>[];
    if ((moisturePercent ?? 0) > 14) {
      parts.add('Độ ẩm cao (${formatNumber(moisturePercent, digits: 1)}%)');
    }
    if ((impurityPercent ?? 0) > 3) {
      parts.add('Tạp chất cao (${formatNumber(impurityPercent, digits: 1)}%)');
    }
    if (moldLevel != null && moldLevel!.isNotEmpty && moldLevel != 'Không') {
      parts.add('Mốc: $moldLevel');
    }
    if (pestLevel != null && pestLevel!.isNotEmpty && pestLevel != 'Không') {
      parts.add('Sâu mọt: $pestLevel');
    }
    if (packagingStatus != null &&
        packagingStatus!.isNotEmpty &&
        packagingStatus != 'Nguyên') {
      parts.add('Bao $packagingStatus');
    }
    if (parts.isEmpty) {
      final trimmed = note?.trim() ?? '';
      return trimmed.isEmpty ? 'Không phát hiện' : trimmed;
    }
    return parts.join(' · ');
  }

  QualitySeverity get severity {
    if (isDraft) return QualitySeverity.pending;
    if (passedInspection != true) return QualitySeverity.high;
    final risky = (moldLevel != null &&
            moldLevel!.isNotEmpty &&
            moldLevel != 'Không') ||
        (pestLevel != null && pestLevel!.isNotEmpty && pestLevel != 'Không') ||
        (moisturePercent ?? 0) > 14 ||
        (impurityPercent ?? 0) > 3;
    return risky ? QualitySeverity.medium : QualitySeverity.low;
  }

  factory QualityInspection.fromJson(Map<String, dynamic> json) =>
      QualityInspection(
        id: JsonReader.integer(json, 'id') ??
            JsonReader.integer(json, 'inspectionId') ??
            0,
        paddyLotId: JsonReader.integer(json, 'paddyLotId') ?? 0,
        lotCode: JsonReader.string(json, 'lotCode'),
        lotStatusCode: JsonReader.string(json, 'lotStatusCode'),
        inspectionType: JsonReader.string(json, 'inspectionType'),
        completedAt: _date(json, 'completedAt'),
        completedBy: JsonReader.integer(json, 'completedBy'),
        targetedBagCount: JsonReader.integer(json, 'targetedBagCount'),
        targetedWeightKg: JsonReader.decimal(json, 'targetedWeightKg'),
        inspectorId: JsonReader.integer(json, 'inspectorId'),
        inspectorName: JsonReader.string(json, 'inspectorName'),
        inspectedAt: _date(json, 'inspectedAt'),
        moisturePercent: JsonReader.decimal(json, 'moisturePercent'),
        impurityPercent: JsonReader.decimal(json, 'impurityPercent'),
        moldLevel: JsonReader.string(json, 'moldLevel'),
        pestLevel: JsonReader.string(json, 'pestLevel'),
        packagingStatus: JsonReader.string(json, 'packagingStatus'),
        passedInspection: JsonReader.boolean(json, 'passedInspection'),
        handling: JsonReader.string(json, 'handling'),
        note: JsonReader.string(json, 'note'),
        affectedWeightKg: JsonReader.decimal(json, 'affectedWeightKg'),
        createdDate: _date(json, 'createdDate'),
        lastModifiedDate: _date(json, 'lastModifiedDate'),
      );
}

class QualityInspectionBagProgress {
  const QualityInspectionBagProgress({
    required this.inspectionId,
    required this.lotId,
    required this.isCompleted,
    required this.totalBags,
    required this.inspectedBags,
    required this.remainingBags,
    required this.normalBags,
    required this.quarantineBags,
    required this.rejectedBags,
    required this.releasedBags,
    required this.items,
    this.inspectionType,
    this.lotCode,
  });

  final int inspectionId;
  final String? inspectionType;
  final int lotId;
  final String? lotCode;
  final bool isCompleted;
  final int totalBags;
  final int inspectedBags;
  final int remainingBags;
  final int normalBags;
  final int quarantineBags;
  final int rejectedBags;
  final int releasedBags;
  final List<QualityInspectionBagResult> items;

  factory QualityInspectionBagProgress.fromJson(Map<String, dynamic> json) =>
      QualityInspectionBagProgress(
        inspectionId: JsonReader.integer(json, 'inspectionId') ?? 0,
        inspectionType: JsonReader.string(json, 'inspectionType'),
        lotId: JsonReader.integer(json, 'lotId') ?? 0,
        lotCode: JsonReader.string(json, 'lotCode'),
        isCompleted: JsonReader.boolean(json, 'isCompleted') ?? false,
        totalBags: JsonReader.integer(json, 'totalBags') ?? 0,
        inspectedBags: JsonReader.integer(json, 'inspectedBags') ?? 0,
        remainingBags: JsonReader.integer(json, 'remainingBags') ?? 0,
        normalBags: JsonReader.integer(json, 'normalBags') ?? 0,
        quarantineBags: JsonReader.integer(json, 'quarantineBags') ?? 0,
        rejectedBags: JsonReader.integer(json, 'rejectedBags') ?? 0,
        releasedBags: JsonReader.integer(json, 'releasedBags') ?? 0,
        items: [
          for (final item
              in JsonReader.list(json, 'items') ?? const <dynamic>[])
            if (item is Map<String, dynamic>)
              QualityInspectionBagResult.fromJson(item),
        ],
      );
}

class QualityInspectionBagResult {
  const QualityInspectionBagResult({
    required this.bagId,
    required this.bagNo,
    required this.weightKg,
    required this.status,
    this.locationId,
    this.locationCode,
    this.qualityResult,
    this.disposition,
    this.moisturePercent,
    this.impurityPercent,
    this.moldLevel,
    this.pestLevel,
    this.packagingStatus,
    this.handling,
    this.note,
    this.inspectedAt,
    this.inspectorName,
  });

  final int bagId;
  final int bagNo;
  final double weightKg;
  final String status;
  final int? locationId;
  final String? locationCode;
  final String? qualityResult;
  final String? disposition;
  final double? moisturePercent;
  final double? impurityPercent;
  final String? moldLevel;
  final String? pestLevel;
  final String? packagingStatus;
  final String? handling;
  final String? note;
  final DateTime? inspectedAt;
  final String? inspectorName;

  bool get isInspected => (qualityResult ?? '').isNotEmpty;

  factory QualityInspectionBagResult.fromJson(Map<String, dynamic> json) =>
      QualityInspectionBagResult(
        bagId: JsonReader.integer(json, 'bagId') ?? 0,
        bagNo: JsonReader.integer(json, 'bagNo') ?? 0,
        weightKg: JsonReader.decimal(json, 'weightKg') ?? 0,
        status: JsonReader.string(json, 'status') ?? 'UNKNOWN',
        locationId: JsonReader.integer(json, 'locationId'),
        locationCode: JsonReader.string(json, 'locationCode'),
        qualityResult: JsonReader.string(json, 'qualityResult'),
        disposition: JsonReader.string(json, 'disposition'),
        moisturePercent: JsonReader.decimal(json, 'moisturePercent'),
        impurityPercent: JsonReader.decimal(json, 'impurityPercent'),
        moldLevel: JsonReader.string(json, 'moldLevel'),
        pestLevel: JsonReader.string(json, 'pestLevel'),
        packagingStatus: JsonReader.string(json, 'packagingStatus'),
        handling: JsonReader.string(json, 'handling'),
        note: JsonReader.string(json, 'note'),
        inspectedAt: _date(json, 'inspectedAt'),
        inspectorName: JsonReader.string(json, 'inspectorName'),
      );
}

class SaveBagInspectionResult {
  const SaveBagInspectionResult({
    required this.bagId,
    required this.qualityResult,
    required this.disposition,
    this.moisturePercent,
    this.impurityPercent,
    this.moldLevel,
    this.pestLevel,
    this.packagingStatus,
    this.handling,
    this.note,
  });

  final int bagId;
  final String qualityResult;
  final String disposition;
  final double? moisturePercent;
  final double? impurityPercent;
  final String? moldLevel;
  final String? pestLevel;
  final String? packagingStatus;
  final String? handling;
  final String? note;

  Map<String, dynamic> toJson() => {
        'bagId': bagId,
        'moisturePercent': moisturePercent,
        'impurityPercent': impurityPercent,
        'moldLevel': _blankToNull(moldLevel),
        'pestLevel': _blankToNull(pestLevel),
        'packagingStatus': _blankToNull(packagingStatus),
        'qualityResult': qualityResult,
        'disposition': disposition,
        'handling': _blankToNull(handling),
        'note': _blankToNull(note),
      };
}

class QualityMoistureConfig {
  const QualityMoistureConfig({
    this.receivingMin,
    this.receivingMax,
    this.storageWarning,
    this.sourceNote,
  });

  final double? receivingMin;
  final double? receivingMax;
  final double? storageWarning;
  final String? sourceNote;

  factory QualityMoistureConfig.fromJson(Map<String, dynamic> json) =>
      QualityMoistureConfig(
        receivingMin: JsonReader.decimal(json, 'receivingMoistureMinPercent'),
        receivingMax: JsonReader.decimal(json, 'receivingMoistureMaxPercent'),
        storageWarning:
            JsonReader.decimal(json, 'storageQcMoistureWarningPercent'),
        sourceNote: JsonReader.string(json, 'sourceNote'),
      );
}

/// Một trang phiếu kiểm định trả về từ `paged-advanced`.
class QualityInspectionPage {
  const QualityInspectionPage({
    required this.items,
    required this.recordsTotal,
    required this.recordsFiltered,
  });

  final List<QualityInspection> items;
  final int recordsTotal;
  final int recordsFiltered;

  static const empty = QualityInspectionPage(
    items: <QualityInspection>[],
    recordsTotal: 0,
    recordsFiltered: 0,
  );
}

/// Một bao trong lô — nguồn để chọn phần cần tách sang cách ly.
class QualityLotBag {
  const QualityLotBag({
    required this.id,
    required this.bagNo,
    required this.weightKg,
    this.status,
    this.locationId,
  });

  final int id;
  final int bagNo;
  final double weightKg;
  final String? status;
  final int? locationId;

  factory QualityLotBag.fromJson(Map<String, dynamic> json) => QualityLotBag(
        id: JsonReader.integer(json, 'id') ?? 0,
        bagNo: JsonReader.integer(json, 'bagNo') ?? 0,
        weightKg: JsonReader.decimal(json, 'weightKg') ?? 0,
        status: JsonReader.string(json, 'status'),
        locationId: JsonReader.integer(json, 'locationId'),
      );
}

/// Thông tin lô phục vụ hiển thị/validate ở màn kiểm định.
class QualityLot {
  const QualityLot({
    required this.id,
    required this.lotCode,
    this.lotType,
    this.productVariantName,
    this.warehouseId,
    this.warehouseName,
    this.locationCode,
    this.statusCode,
    this.statusName,
    this.initialWeightKg = 0,
    this.remainingWeightKg = 0,
    this.bags = const <QualityLotBag>[],
  });

  final int id;
  final String lotCode;
  final String? lotType;
  final String? productVariantName;
  final int? warehouseId;
  final String? warehouseName;
  final String? locationCode;
  final String? statusCode;
  final String? statusName;
  final double initialWeightKg;
  final double remainingWeightKg;
  final List<QualityLotBag> bags;

  bool get isPaddy => lotType?.trim().toUpperCase() == 'PADDY';

  /// Trọng lượng để hiển thị/validate: lô đã nhập kho dùng tồn còn lại, lô chưa
  /// nhập kho dùng trọng lượng ban đầu (giống `lotBasisWeight` của web).
  double? get basisWeightKg => remainingWeightKg > 0
      ? remainingWeightKg
      : (initialWeightKg > 0 ? initialWeightKg : null);

  String get locationLabel {
    final code = locationCode?.trim();
    if (code != null && code.isNotEmpty) return code;
    final warehouse = warehouseName?.trim();
    if (warehouse != null && warehouse.isNotEmpty) return warehouse;
    return warehouseId != null ? 'Kho #$warehouseId' : '—';
  }

  factory QualityLot.fromJson(Map<String, dynamic> json) => QualityLot(
        id: JsonReader.integer(json, 'id') ?? 0,
        lotCode: JsonReader.string(json, 'lotCode') ?? '',
        lotType: JsonReader.string(json, 'lotType'),
        productVariantName: JsonReader.string(json, 'productVariantName'),
        warehouseId: JsonReader.integer(json, 'warehouseId'),
        warehouseName: JsonReader.string(json, 'warehouseName'),
        locationCode: JsonReader.string(json, 'locationCode'),
        statusCode: JsonReader.string(json, 'statusCode'),
        statusName: JsonReader.string(json, 'statusName'),
        initialWeightKg: JsonReader.decimal(json, 'initialWeightKg') ?? 0,
        remainingWeightKg: JsonReader.decimal(json, 'remainingWeightKg') ?? 0,
        bags: [
          for (final bag in JsonReader.list(json, 'bags') ?? const <dynamic>[])
            if (bag is Map<String, dynamic>) QualityLotBag.fromJson(bag),
        ],
      );
}

/// Payload PUT /quality-inspections — khớp `UpdateQualityInspectionDto`.
class QualityInspectionUpdate {
  const QualityInspectionUpdate({
    required this.id,
    required this.paddyLotId,
    required this.inspectedAt,
    required this.passedInspection,
    this.inspectorId,
    this.moisturePercent,
    this.impurityPercent,
    this.moldLevel,
    this.pestLevel,
    this.packagingStatus,
    this.handling,
    this.note,
    this.affectedWeightKg,
    this.affectedBagIds = const <int>[],
  });

  final int id;
  final int paddyLotId;
  final DateTime inspectedAt;
  final bool passedInspection;

  /// Người kiểm định — mobile luôn gắn người đang sửa phiếu, giống web.
  final int? inspectorId;
  final double? moisturePercent;
  final double? impurityPercent;
  final String? moldLevel;
  final String? pestLevel;
  final String? packagingStatus;
  final String? handling;
  final String? note;
  final double? affectedWeightKg;
  final List<int> affectedBagIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'paddyLotId': paddyLotId,
        'inspectorId': inspectorId,
        'inspectedAt': inspectedAt.toUtc().toIso8601String(),
        'moisturePercent': moisturePercent,
        'impurityPercent': impurityPercent,
        'moldLevel': _blankToNull(moldLevel),
        'pestLevel': _blankToNull(pestLevel),
        'packagingStatus': _blankToNull(packagingStatus),
        'passedInspection': passedInspection,
        'handling': _blankToNull(handling),
        'note': _blankToNull(note),
        'affectedWeightKg': affectedWeightKg,
        'affectedBagIds': affectedBagIds,
      };
}

/// Payload POST /quality-inspections - khop CreateQualityInspectionDto.
class QualityInspectionCreate {
  const QualityInspectionCreate({
    required this.paddyLotId,
    required this.inspectedAt,
    required this.passedInspection,
    this.inspectorId,
    this.moisturePercent,
    this.impurityPercent,
    this.moldLevel,
    this.pestLevel,
    this.packagingStatus,
    this.handling,
    this.note,
    this.affectedWeightKg,
    this.affectedBagIds = const <int>[],
  });

  final int paddyLotId;
  final int? inspectorId;
  final DateTime inspectedAt;
  final double? moisturePercent;
  final double? impurityPercent;
  final String? moldLevel;
  final String? pestLevel;
  final String? packagingStatus;
  final bool passedInspection;
  final String? handling;
  final String? note;
  final double? affectedWeightKg;
  final List<int> affectedBagIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'paddyLotId': paddyLotId,
        'inspectorId': inspectorId,
        'inspectedAt': inspectedAt.toUtc().toIso8601String(),
        'moisturePercent': moisturePercent,
        'impurityPercent': impurityPercent,
        'moldLevel': _blankToNull(moldLevel),
        'pestLevel': _blankToNull(pestLevel),
        'packagingStatus': _blankToNull(packagingStatus),
        'passedInspection': passedInspection,
        'handling': _blankToNull(handling),
        'note': _blankToNull(note),
        'affectedWeightKg': affectedWeightKg,
        'affectedBagIds': affectedBagIds,
      };
}

/// Danh mục lựa chọn — dùng đúng vocab entity backend như web.
class QualityVocab {
  const QualityVocab._();

  static const mold = <String>['Không', 'Nhẹ', 'Nặng'];
  static const pest = <String>['Không', 'Có dấu hiệu', 'Cần xử lý'];
  static const packaging = <String>['Nguyên', 'Rách', 'Ẩm'];
  static const handling = <String>[
    'Phơi',
    'Sấy',
    'Đảo kho',
    'Cách ly',
    'Bán nhanh',
  ];
}

class QualityInspectionException implements Exception {
  const QualityInspectionException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _date(Map<String, dynamic> json, String key) =>
    DateTime.tryParse(JsonReader.string(json, key) ?? '')?.toLocal();
