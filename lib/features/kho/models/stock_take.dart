import '../../../core/api/json_reader.dart';

/// Kết quả chấm chất lượng của MỘT BAO khi kiểm kê.
enum BagQualityResult { none, pass, issue }

extension BagQualityResultX on BagQualityResult {
  String? get code => switch (this) {
        BagQualityResult.none => null,
        BagQualityResult.pass => 'PASS',
        BagQualityResult.issue => 'ISSUE_DETECTED',
      };

  String get label => switch (this) {
        BagQualityResult.none => 'Chưa chấm',
        BagQualityResult.pass => 'Đạt',
        BagQualityResult.issue => 'Có vấn đề',
      };

  bool get isIssue => this == BagQualityResult.issue;

  static BagQualityResult fromCode(String? code) =>
      switch ((code ?? '').toUpperCase()) {
        'PASS' => BagQualityResult.pass,
        'ISSUE_DETECTED' => BagQualityResult.issue,
        _ => BagQualityResult.none,
      };
}

/// Cách xử lý một bao sau khi kiểm kê.
enum BagDisposition { keep, quarantine, dispose, release }

extension BagDispositionX on BagDisposition {
  String get code => switch (this) {
        BagDisposition.keep => 'KEEP',
        BagDisposition.quarantine => 'QUARANTINE',
        BagDisposition.dispose => 'DISPOSE',
        BagDisposition.release => 'RELEASE',
      };

  String get label => switch (this) {
        BagDisposition.keep => 'Giữ nguyên',
        BagDisposition.quarantine => 'Chuyển cách ly',
        BagDisposition.dispose => 'Bao hỏng — bỏ cả bao',
        BagDisposition.release => 'Rút về khu thường',
      };

  /// Bao rời khỏi vị trí đang kiểm → phải chọn vị trí đích.
  bool get needsTarget =>
      this == BagDisposition.quarantine || this == BagDisposition.release;

  static BagDisposition fromCode(String? code) =>
      switch ((code ?? 'KEEP').toUpperCase()) {
        'QUARANTINE' => BagDisposition.quarantine,
        'DISPOSE' => BagDisposition.dispose,
        'RELEASE' => BagDisposition.release,
        _ => BagDisposition.keep,
      };
}

/// Một BAO trong dòng kiểm kê.
///
/// Kho gạo lưu hàng theo bao nên đây mới là đơn vị kiểm đếm thật; kg là hệ quả.
class StockTakeBag {
  StockTakeBag({
    required this.id,
    required this.paddyLotBagId,
    required this.bagNo,
    required this.systemWeightKg,
    required this.pickSequence,
    required this.restowSequence,
    this.qrCode,
    this.lotCode,
    this.countedWeightKg,
    this.counted = false,
    this.scannedByQr = false,
    this.isUnexpected = false,
    this.quality = BagQualityResult.none,
    this.moldLevel,
    this.pestLevel,
    this.packagingStatus,
    this.qualityNote,
    this.disposition = BagDisposition.keep,
    this.targetLocationId,
    this.targetLocationCode,
    this.targetZoneName,
    this.dispositionNote,
  });

  final int id;
  final int paddyLotBagId;
  final int bagNo;
  final String? qrCode;
  final String? lotCode;
  final double systemWeightKg;

  /// Thứ tự LẤY RA: 1 = bao trên cùng cột. Thủ kho dỡ cột từ trên xuống.
  final int pickSequence;

  /// Thứ tự CẤT LẠI: bao lấy ra sau cùng được cất vào cột trước.
  final int restowSequence;

  /// null = không cân bao này → giữ nguyên kg sổ sách khi duyệt.
  double? countedWeightKg;
  bool counted;
  bool scannedByQr;
  final bool isUnexpected;

  BagQualityResult quality;
  String? moldLevel;
  String? pestLevel;
  String? packagingStatus;
  String? qualityNote;

  BagDisposition disposition;
  int? targetLocationId;
  String? targetLocationCode;
  String? targetZoneName;
  String? dispositionNote;

  /// Kg tìm thấy: đã cân thì lấy số cân, không cân thì giữ kg sổ sách.
  double get effectiveKg => counted ? (countedWeightKg ?? systemWeightKg) : 0;

  /// Bao vẫn nằm lại đúng vị trí sau khi xử lý.
  bool get staysAtLocation => counted && disposition == BagDisposition.keep;

  factory StockTakeBag.fromJson(Map<String, dynamic> json) => StockTakeBag(
        id: JsonReader.integer(json, 'id') ?? 0,
        paddyLotBagId: JsonReader.integer(json, 'paddyLotBagId') ?? 0,
        bagNo: JsonReader.integer(json, 'bagNo') ?? 0,
        qrCode: JsonReader.string(json, 'qrCode'),
        lotCode: JsonReader.string(json, 'lotCode'),
        systemWeightKg: JsonReader.decimal(json, 'systemWeightKg') ?? 0,
        pickSequence: JsonReader.integer(json, 'pickSequence') ?? 0,
        restowSequence: JsonReader.integer(json, 'restowSequence') ?? 0,
        countedWeightKg: JsonReader.decimal(json, 'countedWeightKg'),
        counted: JsonReader.boolean(json, 'counted') ?? false,
        scannedByQr: JsonReader.boolean(json, 'scannedByQr') ?? false,
        isUnexpected: JsonReader.boolean(json, 'isUnexpected') ?? false,
        quality: BagQualityResultX.fromCode(JsonReader.string(json, 'qualityResult')),
        moldLevel: JsonReader.string(json, 'moldLevel'),
        pestLevel: JsonReader.string(json, 'pestLevel'),
        packagingStatus: JsonReader.string(json, 'packagingStatus'),
        qualityNote: JsonReader.string(json, 'qualityNote'),
        disposition: BagDispositionX.fromCode(JsonReader.string(json, 'disposition')),
        targetLocationId: JsonReader.integer(json, 'targetLocationId'),
        targetLocationCode: JsonReader.string(json, 'targetLocationCode'),
        targetZoneName: JsonReader.string(json, 'targetZoneName'),
        dispositionNote: JsonReader.string(json, 'dispositionNote'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'paddyLotBagId': paddyLotBagId,
        'counted': counted,
        'scannedByQr': scannedByQr,
        'countedWeightKg': countedWeightKg,
        'qualityResult': quality.code,
        'moldLevel': moldLevel,
        'pestLevel': pestLevel,
        'packagingStatus': packagingStatus,
        'qualityNote': qualityNote?.trim(),
        'disposition': disposition.code,
        'targetLocationId': targetLocationId,
        'dispositionNote': dispositionNote?.trim(),
      };
}

/// Một dòng kiểm kê = một lô tại một vị trí.
class StockTakeLine {
  StockTakeLine({
    required this.id,
    required this.systemQuantity,
    required this.systemBagCount,
    required this.bags,
    this.productVariantName,
    this.sku,
    this.lotCode,
    this.zoneName,
    this.locationCode,
    this.isQuarantine = false,
    this.actualQuantity,
    this.countedBagCount,
    this.varianceReason,
    this.adjustedBagCount,
    this.adjustedWeightKg,
    this.note,
    this.recountConfirmed = false,
    this.varianceSeverity = 'NONE',
  });

  final int id;
  final String? productVariantName;
  final String? sku;
  final String? lotCode;
  final String? zoneName;
  final String? locationCode;
  final bool isQuarantine;

  final double systemQuantity;
  final int systemBagCount;
  final List<StockTakeBag> bags;

  double? actualQuantity;
  int? countedBagCount;

  /// Lý do lệch — bắt buộc khi lệch số bao hoặc lệch kg.
  String? varianceReason;

  /// Chỉnh lý sau kiểm kê (null = lấy đúng số đếm/cân được).
  int? adjustedBagCount;
  double? adjustedWeightKg;

  String? note;
  bool recountConfirmed;
  final String varianceSeverity;

  /// Dòng có quản lý theo bao không (dữ liệu cũ thì không).
  bool get hasBags => bags.isNotEmpty;

  int get countedBags => adjustedBagCount ?? bags.where((b) => b.counted).length;

  /// Tổng kg suy từ các bao ĐÃ tìm thấy. Bao không cân giữ nguyên kg sổ sách —
  /// không quy về 0 và cũng không chia đều chênh lệch.
  double get countedKg =>
      adjustedWeightKg ?? bags.fold<double>(0, (s, b) => s + b.effectiveKg);

  double get effectiveActualKg => hasBags ? countedKg : (actualQuantity ?? 0);

  int get bagDifference => countedBags - systemBagCount;

  int get quarantineBags =>
      bags.where((b) => b.disposition == BagDisposition.quarantine).length;
  int get disposedBags =>
      bags.where((b) => b.disposition == BagDisposition.dispose).length;
  int get releasedBags =>
      bags.where((b) => b.disposition == BagDisposition.release).length;

  bool get touched => hasBags
      ? bags.any((b) => b.counted || b.countedWeightKg != null)
      : actualQuantity != null;

  bool get hasVariance =>
      touched &&
      (bagDifference != 0 || (effectiveActualKg - systemQuantity).abs() >= 0.05);

  String get locationLabel {
    final zone = zoneName?.trim();
    final slot = locationCode?.trim();
    if ((zone ?? '').isEmpty && (slot ?? '').isEmpty) return '—';
    return [zone, slot].where((x) => (x ?? '').isNotEmpty).join('/');
  }

  String get title {
    final name = (productVariantName ?? sku ?? '').trim();
    final lot = (lotCode ?? '').trim();
    if (name.isNotEmpty && lot.isNotEmpty) return '$name ($lot)';
    if (name.isNotEmpty) return name;
    if (lot.isNotEmpty) return 'Lô $lot';
    return 'Dòng #$id';
  }

  factory StockTakeLine.fromJson(Map<String, dynamic> json) => StockTakeLine(
        id: JsonReader.integer(json, 'id') ?? 0,
        productVariantName: JsonReader.string(json, 'productVariantName') ??
            JsonReader.string(json, 'variantName'),
        sku: JsonReader.string(json, 'sku') ?? JsonReader.string(json, 'sKU'),
        lotCode: JsonReader.string(json, 'lotCode'),
        zoneName: JsonReader.string(json, 'zoneName'),
        locationCode: JsonReader.string(json, 'locationCode'),
        isQuarantine: JsonReader.boolean(json, 'isQuarantine') ?? false,
        systemQuantity: JsonReader.decimal(json, 'systemQuantity') ?? 0,
        systemBagCount: JsonReader.integer(json, 'systemBagCount') ?? 0,
        actualQuantity: JsonReader.decimal(json, 'actualQuantity'),
        countedBagCount: JsonReader.integer(json, 'countedBagCount'),
        varianceReason: JsonReader.string(json, 'varianceReason'),
        adjustedBagCount: JsonReader.integer(json, 'adjustedBagCount'),
        adjustedWeightKg: JsonReader.decimal(json, 'adjustedWeightKg'),
        note: JsonReader.string(json, 'note'),
        recountConfirmed: JsonReader.boolean(json, 'recountConfirmed') ?? false,
        varianceSeverity: JsonReader.string(json, 'varianceSeverity') ?? 'NONE',
        bags: [
          for (final raw in JsonReader.list(json, 'bags') ?? const [])
            if (raw is Map<String, dynamic>) StockTakeBag.fromJson(raw),
        ]..sort((a, b) => a.pickSequence.compareTo(b.pickSequence)),
      );

  Map<String, dynamic> toSaveJson() => {
        'id': id,
        // Dòng theo bao: backend tự tính tổng kg từ các bao, không tin số này.
        if (!hasBags) 'actualQuantity': actualQuantity,
        'note': note?.trim(),
        'varianceReason': varianceReason?.trim(),
        'adjustedBagCount': adjustedBagCount,
        'adjustedWeightKg': adjustedWeightKg,
        'recountConfirmed': recountConfirmed,
        'bags': [for (final bag in bags) bag.toJson()],
      };
}

/// Phiếu kiểm kê.
class StockTakeDetail {
  StockTakeDetail({
    required this.id,
    required this.code,
    required this.warehouseId,
    required this.warehouseName,
    required this.statusCode,
    required this.statusName,
    required this.lines,
    this.scopeDisplay = '',
    this.isQuarantineScope = false,
    this.note,
    this.createdDate,
  });

  final int id;
  final String code;
  final int warehouseId;
  final String warehouseName;
  final String statusCode;
  final String statusName;
  final String scopeDisplay;

  /// Phiếu kiểm kê KHU CÁCH LY: bao đạt được rút ra cất về cột thường.
  final bool isQuarantineScope;
  final String? note;
  final DateTime? createdDate;
  final List<StockTakeLine> lines;

  bool get isDraft => statusCode.toUpperCase() == 'DRAFT';

  int get totalBags => lines.fold(0, (s, l) => s + l.systemBagCount);
  int get countedBags => lines.fold(0, (s, l) => s + l.countedBags);
  int get missingBags =>
      lines.fold(0, (s, l) => s + (l.bagDifference < 0 ? -l.bagDifference : 0));
  int get quarantineBags => lines.fold(0, (s, l) => s + l.quarantineBags);
  int get disposedBags => lines.fold(0, (s, l) => s + l.disposedBags);
  int get releasedBags => lines.fold(0, (s, l) => s + l.releasedBags);
  bool get hasQualityIssue =>
      lines.any((l) => l.bags.any((b) => b.quality.isIssue));

  factory StockTakeDetail.fromJson(Map<String, dynamic> json) => StockTakeDetail(
        id: JsonReader.integer(json, 'id') ?? 0,
        code: JsonReader.string(json, 'stCode') ?? 'ST',
        warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
        warehouseName: JsonReader.string(json, 'warehouseName') ?? 'Kho',
        statusCode: JsonReader.string(json, 'stockTakeStatusCode') ?? 'DRAFT',
        statusName: JsonReader.string(json, 'stockTakeStatusName') ?? 'Nháp',
        scopeDisplay: JsonReader.string(json, 'scopeDisplay') ?? '',
        isQuarantineScope: JsonReader.boolean(json, 'isQuarantineScope') ?? false,
        note: JsonReader.string(json, 'note'),
        createdDate:
            DateTime.tryParse(JsonReader.string(json, 'createdDate') ?? '')?.toLocal(),
        lines: [
          for (final raw in JsonReader.list(json, 'stockTakeItems') ?? const [])
            if (raw is Map<String, dynamic>) StockTakeLine.fromJson(raw),
        ],
      );
}

/// Dòng trong danh sách phiếu kiểm kê.
class StockTakeSummaryRow {
  const StockTakeSummaryRow({
    required this.id,
    required this.code,
    required this.warehouseName,
    required this.statusCode,
    required this.statusName,
    this.scopeDisplay = '',
    this.createdDate,
  });

  final int id;
  final String code;
  final String warehouseName;
  final String statusCode;
  final String statusName;
  final String scopeDisplay;
  final DateTime? createdDate;

  bool get isDraft => statusCode.toUpperCase() == 'DRAFT';

  factory StockTakeSummaryRow.fromJson(Map<String, dynamic> json) =>
      StockTakeSummaryRow(
        id: JsonReader.integer(json, 'id') ?? 0,
        code: JsonReader.string(json, 'stCode') ?? 'ST',
        warehouseName: JsonReader.string(json, 'warehouseName') ?? 'Kho',
        statusCode: JsonReader.string(json, 'stockTakeStatusCode') ?? '',
        statusName: JsonReader.string(json, 'stockTakeStatusName') ?? '',
        scopeDisplay: JsonReader.string(json, 'scopeDisplay') ?? '',
        createdDate:
            DateTime.tryParse(JsonReader.string(json, 'createdDate') ?? '')?.toLocal(),
      );
}

/// Kết quả quét một mã QR bao khi đang kiểm kê.
class ScanBagResult {
  const ScanBagResult({
    required this.matched,
    required this.message,
    this.reason,
    this.stockTakeItemId,
    this.bagId,
    this.paddyLotBagId,
    this.bagNo,
    this.lotCode,
    this.locationCode,
  });

  final bool matched;
  final String message;
  final String? reason;
  final int? stockTakeItemId;

  /// Id dòng StockTakeItemBag trong phiếu (không phải id bao vật lý).
  final int? bagId;
  final int? paddyLotBagId;
  final int? bagNo;
  final String? lotCode;
  final String? locationCode;

  bool get alreadyCounted => reason == 'ALREADY_COUNTED';
  bool get pulledIn => reason == 'PULLED_IN';

  factory ScanBagResult.fromJson(Map<String, dynamic> json) => ScanBagResult(
        matched: JsonReader.boolean(json, 'matched') ?? false,
        message: JsonReader.string(json, 'message') ?? '',
        reason: JsonReader.string(json, 'reason'),
        stockTakeItemId: JsonReader.integer(json, 'stockTakeItemId'),
        bagId: JsonReader.integer(json, 'stockTakeItemBagId'),
        paddyLotBagId: JsonReader.integer(json, 'paddyLotBagId'),
        bagNo: JsonReader.integer(json, 'bagNo'),
        lotCode: JsonReader.string(json, 'lotCode'),
        locationCode: JsonReader.string(json, 'locationCode'),
      );
}

/// Gợi ý vị trí đích cho bao (ô cách ly hoặc cột thường).
class BagTargetSuggestion {
  const BagTargetSuggestion({
    required this.locationId,
    required this.zoneName,
    required this.isRecommended,
    this.locationCode,
    this.availableKg = 0,
    this.reason = '',
  });

  final int locationId;
  final String zoneName;
  final String? locationCode;
  final double availableKg;
  final String reason;
  final bool isRecommended;

  String get label =>
      '${isRecommended ? '★ ' : ''}$zoneName / ${locationCode ?? '#$locationId'}';

  factory BagTargetSuggestion.fromJson(Map<String, dynamic> json) =>
      BagTargetSuggestion(
        locationId: JsonReader.integer(json, 'locationId') ?? 0,
        zoneName: JsonReader.string(json, 'zoneName') ?? '',
        locationCode: JsonReader.string(json, 'locationCode'),
        availableKg: JsonReader.decimal(json, 'availableKg') ?? 0,
        reason: JsonReader.string(json, 'reason') ?? '',
        isRecommended: JsonReader.boolean(json, 'isRecommended') ?? false,
      );
}

/// Một lựa chọn phạm vi kiểm kê (khu / cột / lô) đang có bao.
class StockTakeScopeOption {
  const StockTakeScopeOption({
    required this.label,
    required this.bagCount,
    required this.isQuarantine,
    this.zoneName,
    this.locationId,
    this.paddyLotId,
  });

  final String label;
  final int bagCount;
  final bool isQuarantine;
  final String? zoneName;
  final int? locationId;
  final int? paddyLotId;
}

class StockTakeScopeOptions {
  const StockTakeScopeOptions({
    this.zones = const [],
    this.columns = const [],
    this.lots = const [],
  });

  final List<StockTakeScopeOption> zones;
  final List<StockTakeScopeOption> columns;
  final List<StockTakeScopeOption> lots;

  factory StockTakeScopeOptions.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(String key) => [
          for (final raw in JsonReader.list(json, key) ?? const [])
            if (raw is Map<String, dynamic>) raw,
        ];

    return StockTakeScopeOptions(
      zones: [
        for (final row in rows('zones'))
          StockTakeScopeOption(
            zoneName: JsonReader.string(row, 'zoneName'),
            bagCount: JsonReader.integer(row, 'bagCount') ?? 0,
            isQuarantine: JsonReader.boolean(row, 'isQuarantine') ?? false,
            label: '${JsonReader.string(row, 'zoneName') ?? '—'} '
                '(${JsonReader.integer(row, 'columnCount') ?? 0} cột, '
                '${JsonReader.integer(row, 'bagCount') ?? 0} bao)',
          ),
      ],
      columns: [
        for (final row in rows('columns'))
          StockTakeScopeOption(
            locationId: JsonReader.integer(row, 'locationId'),
            zoneName: JsonReader.string(row, 'zoneName'),
            bagCount: JsonReader.integer(row, 'bagCount') ?? 0,
            isQuarantine: JsonReader.boolean(row, 'isQuarantine') ?? false,
            label: '${JsonReader.string(row, 'zoneName') ?? '—'} / '
                '${JsonReader.string(row, 'locationCode') ?? '#${JsonReader.integer(row, 'locationId')}'} '
                '(${JsonReader.integer(row, 'bagCount') ?? 0} bao)',
          ),
      ],
      lots: [
        for (final row in rows('lots'))
          StockTakeScopeOption(
            paddyLotId: JsonReader.integer(row, 'paddyLotId'),
            bagCount: JsonReader.integer(row, 'bagCount') ?? 0,
            isQuarantine: JsonReader.boolean(row, 'isQuarantine') ?? false,
            label: '${JsonReader.string(row, 'lotCode') ?? '—'} '
                '(${JsonReader.integer(row, 'bagCount') ?? 0} bao / '
                '${JsonReader.integer(row, 'columnCount') ?? 0} cột)',
          ),
      ],
    );
  }
}

/// Kết quả quét QR khu/cột/lô để chọn phạm vi kiểm kê.
class StockTakeScopeResolve {
  const StockTakeScopeResolve({
    required this.matched,
    required this.message,
    this.scopeType,
    this.zoneName,
    this.locationId,
    this.paddyLotId,
    this.warehouseId,
    this.isQuarantine = false,
    this.bagCount = 0,
  });

  final bool matched;
  final String message;

  /// ZONE | COLUMN | LOT
  final String? scopeType;
  final String? zoneName;
  final int? locationId;
  final int? paddyLotId;
  final int? warehouseId;
  final bool isQuarantine;
  final int bagCount;

  factory StockTakeScopeResolve.fromJson(Map<String, dynamic> json) =>
      StockTakeScopeResolve(
        matched: JsonReader.boolean(json, 'matched') ?? false,
        message: JsonReader.string(json, 'message') ?? '',
        scopeType: JsonReader.string(json, 'scopeType'),
        zoneName: JsonReader.string(json, 'zoneName'),
        locationId: JsonReader.integer(json, 'locationId'),
        paddyLotId: JsonReader.integer(json, 'paddyLotId'),
        warehouseId: JsonReader.integer(json, 'warehouseId'),
        isQuarantine: JsonReader.boolean(json, 'isQuarantine') ?? false,
        bagCount: JsonReader.integer(json, 'bagCount') ?? 0,
      );
}
