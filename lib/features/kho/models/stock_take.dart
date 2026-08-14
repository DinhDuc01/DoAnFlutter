import '../../../core/api/json_reader.dart';

/// Tình trạng chất lượng ghi nhận khi kiểm kê.
enum StockTakeQuality { ok, wet, pest, tornBag, other }

extension StockTakeQualityX on StockTakeQuality {
  String get code => switch (this) {
        StockTakeQuality.ok => 'OK',
        StockTakeQuality.wet => 'WET',
        StockTakeQuality.pest => 'PEST',
        StockTakeQuality.tornBag => 'TORN_BAG',
        StockTakeQuality.other => 'OTHER',
      };

  String get label => switch (this) {
        StockTakeQuality.ok => 'Đạt',
        StockTakeQuality.wet => 'Ẩm/mốc',
        StockTakeQuality.pest => 'Mọt',
        StockTakeQuality.tornBag => 'Rách bao',
        StockTakeQuality.other => 'Khác',
      };

  bool get isFailed => this != StockTakeQuality.ok;

  static StockTakeQuality fromCode(String? code) =>
      switch ((code ?? 'OK').toUpperCase()) {
        'WET' => StockTakeQuality.wet,
        'PEST' => StockTakeQuality.pest,
        'TORN_BAG' => StockTakeQuality.tornBag,
        'OTHER' => StockTakeQuality.other,
        _ => StockTakeQuality.ok,
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
    this.qrCode,
    this.countedWeightKg,
    this.counted = false,
    this.scannedByQr = false,
    this.isUnexpected = false,
    this.quality = StockTakeQuality.ok,
    this.note,
  });

  final int id;
  final int paddyLotBagId;
  final int bagNo;
  final String? qrCode;
  final double systemWeightKg;

  /// null = không cân bao này → giữ nguyên kg sổ sách khi duyệt.
  double? countedWeightKg;
  bool counted;
  bool scannedByQr;
  final bool isUnexpected;
  StockTakeQuality quality;
  String? note;

  /// Khối lượng dùng để cộng tổng: đã cân thì lấy số cân, không thì lấy sổ sách.
  double get effectiveKg => countedWeightKg ?? systemWeightKg;

  factory StockTakeBag.fromJson(Map<String, dynamic> json) => StockTakeBag(
        id: JsonReader.integer(json, 'id') ?? 0,
        paddyLotBagId: JsonReader.integer(json, 'paddyLotBagId') ?? 0,
        bagNo: JsonReader.integer(json, 'bagNo') ?? 0,
        qrCode: JsonReader.string(json, 'qrCode'),
        systemWeightKg: JsonReader.decimal(json, 'systemWeightKg') ?? 0,
        countedWeightKg: JsonReader.decimal(json, 'countedWeightKg'),
        counted: JsonReader.boolean(json, 'counted') ?? false,
        scannedByQr: JsonReader.boolean(json, 'scannedByQr') ?? false,
        isUnexpected: JsonReader.boolean(json, 'isUnexpected') ?? false,
        quality: StockTakeQualityX.fromCode(JsonReader.string(json, 'qualityStatus')),
        note: JsonReader.string(json, 'note'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'paddyLotBagId': paddyLotBagId,
        'qrCode': qrCode,
        'counted': counted,
        'scannedByQr': scannedByQr,
        'countedWeightKg': countedWeightKg,
        'qualityStatus': quality.code,
        'note': note,
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
    this.actualQuantity,
    this.countedBagCount,
    this.quality = StockTakeQuality.ok,
    this.qualityNote,
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

  final double systemQuantity;
  final int systemBagCount;
  final List<StockTakeBag> bags;

  double? actualQuantity;
  int? countedBagCount;
  StockTakeQuality quality;
  String? qualityNote;
  String? note;
  bool recountConfirmed;
  final String varianceSeverity;

  /// Dòng có quản lý theo bao không (hàng không theo lô thì không).
  bool get hasBags => bags.isNotEmpty;

  int get countedBags => bags.where((b) => b.counted).length;

  /// Tổng kg suy từ các bao ĐÃ tìm thấy. Bao không cân giữ nguyên kg sổ sách —
  /// không quy về 0 và cũng không chia đều chênh lệch.
  double get countedKg =>
      bags.where((b) => b.counted).fold<double>(0, (s, b) => s + b.effectiveKg);

  double get effectiveActualKg =>
      hasBags ? countedKg : (actualQuantity ?? 0);

  int get bagDifference => countedBags - systemBagCount;

  bool get touched => hasBags ? bags.any((b) => b.counted) : actualQuantity != null;

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
        systemQuantity: JsonReader.decimal(json, 'systemQuantity') ?? 0,
        systemBagCount: JsonReader.integer(json, 'systemBagCount') ??
            (JsonReader.decimal(json, 'systemQuantity')?.round() ?? 0),
        actualQuantity: JsonReader.decimal(json, 'actualQuantity'),
        countedBagCount: JsonReader.integer(json, 'countedBagCount'),
        quality: StockTakeQualityX.fromCode(JsonReader.string(json, 'qualityStatus')),
        qualityNote: JsonReader.string(json, 'qualityNote'),
        note: JsonReader.string(json, 'note'),
        recountConfirmed: JsonReader.boolean(json, 'recountConfirmed') ?? false,
        varianceSeverity: JsonReader.string(json, 'varianceSeverity') ?? 'NONE',
        bags: [
          for (final raw in JsonReader.list(json, 'bags') ?? const [])
            if (raw is Map<String, dynamic>) StockTakeBag.fromJson(raw),
        ]..sort((a, b) => a.bagNo.compareTo(b.bagNo)),
      );

  Map<String, dynamic> toSaveJson() => {
        'id': id,
        'actualQuantity': effectiveActualKg,
        'note': note?.trim(),
        'qrScanned': bags.any((b) => b.scannedByQr),
        'recountConfirmed': recountConfirmed,
        'qualityStatus': quality.code,
        'qualityNote': qualityNote?.trim(),
        if (hasBags) 'bags': [for (final bag in bags) bag.toJson()],
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
  final String? note;
  final DateTime? createdDate;
  final List<StockTakeLine> lines;

  bool get isDraft => statusCode.toUpperCase() == 'DRAFT';

  int get totalBags => lines.fold(0, (s, l) => s + l.systemBagCount);
  int get countedBags => lines.fold(0, (s, l) => s + l.countedBags);
  int get missingBags =>
      lines.fold(0, (s, l) => s + (l.bagDifference < 0 ? -l.bagDifference : 0));
  bool get hasQualityIssue => lines.any((l) => l.quality.isFailed);

  factory StockTakeDetail.fromJson(Map<String, dynamic> json) => StockTakeDetail(
        id: JsonReader.integer(json, 'id') ?? 0,
        code: JsonReader.string(json, 'stCode') ?? 'ST',
        warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
        warehouseName: JsonReader.string(json, 'warehouseName') ?? 'Kho',
        statusCode: JsonReader.string(json, 'stockTakeStatusCode') ?? 'DRAFT',
        statusName: JsonReader.string(json, 'stockTakeStatusName') ?? 'Nháp',
        scopeDisplay: JsonReader.string(json, 'scopeDisplay') ?? '',
        note: JsonReader.string(json, 'note'),
        createdDate: DateTime.tryParse(JsonReader.string(json, 'createdDate') ?? '')?.toLocal(),
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

/// Kết quả tra một mã QR bao khi đang kiểm kê.
class ScanBagResult {
  const ScanBagResult({
    required this.matched,
    required this.message,
    this.reason,
    this.stockTakeItemId,
    this.bagId,
    this.paddyLotBagId,
    this.lotCode,
    this.locationCode,
  });

  final bool matched;
  final String message;
  final String? reason;
  final int? stockTakeItemId;
  final int? bagId;
  final int? paddyLotBagId;
  final String? lotCode;
  final String? locationCode;

  bool get alreadyCounted => reason == 'ALREADY_COUNTED';

  factory ScanBagResult.fromJson(Map<String, dynamic> json) {
    final bag = JsonReader.map(json, 'bag');
    return ScanBagResult(
      matched: JsonReader.boolean(json, 'matched') ?? false,
      message: JsonReader.string(json, 'message') ?? '',
      reason: JsonReader.string(json, 'reason'),
      stockTakeItemId: JsonReader.integer(json, 'stockTakeItemId'),
      bagId: bag == null ? null : JsonReader.integer(bag, 'id'),
      paddyLotBagId: bag == null ? null : JsonReader.integer(bag, 'paddyLotBagId'),
      lotCode: JsonReader.string(json, 'lotCode'),
      locationCode: JsonReader.string(json, 'locationCode'),
    );
  }
}
