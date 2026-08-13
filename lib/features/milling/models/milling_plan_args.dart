/// Tham số điều hướng sang màn Xay xát.
///
/// Web có ô "Loại kế hoạch" với hai lựa chọn `SALES_ORDER` (đơn bán cần xay) và
/// `PRODUCTION_PLAN` (kế hoạch sản xuất / lệnh độc lập). Khi mở màn xay xát từ
/// một đơn bán, mobile truyền sẵn [sourceType] = `SALES_ORDER` kèm
/// [salesOrderId] để màn xay xát tự chọn đúng loại kế hoạch và đơn bán tương
/// ứng — giống hành vi của web.
class MillingPlanArgs {
  const MillingPlanArgs({
    this.sourceType = millingSourceProductionPlan,
    this.salesOrderId,
    this.salesOrderCode,
    this.remainingRiceKg,
  });

  /// Khởi tạo nhanh cho luồng "đơn bán cần xay".
  const MillingPlanArgs.forSalesOrder({
    required int this.salesOrderId,
    this.salesOrderCode,
    this.remainingRiceKg,
  }) : sourceType = millingSourceSalesOrder;

  /// `SALES_ORDER` | `PRODUCTION_PLAN` — khớp giá trị web gửi lên backend.
  final String sourceType;

  final int? salesOrderId;
  final String? salesOrderCode;

  /// Khối lượng gạo còn thiếu của đơn (kg) — dùng để gợi ý sản lượng cần xay.
  final double? remainingRiceKg;

  bool get isSalesOrder => sourceType == millingSourceSalesOrder;
}

const String millingSourceSalesOrder = 'SALES_ORDER';
const String millingSourceProductionPlan = 'PRODUCTION_PLAN';
