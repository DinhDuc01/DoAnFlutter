import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/quality_inspection_readonly_repository.dart';
import '../../models/quality_inspection_readonly.dart';

class QualityInspectionDetailScreen extends StatelessWidget {
  const QualityInspectionDetailScreen({
    required this.repository,
    required this.item,
    super.key,
  });

  final QualityInspectionReadOnlyRepository repository;
  final QualityInspectionReadOnly item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(title: const Text('Chi tiết kiểm định')),
      body: FutureBuilder<List<Object>>(
        future: Future.wait<Object>([
          if (item.inspectionId != null) repository.getDetail(item.inspectionId!),
          if (item.paddyLotId != null) repository.getLot(item.paddyLotId!),
          if (item.paddyLotId != null) repository.getHistory(item.paddyLotId!),
        ]),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Không tải được chi tiết: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final values = snapshot.data!;
          final detail = values.firstWhere(
            (value) => value is QualityInspectionReadOnly,
            orElse: () => item,
          ) as QualityInspectionReadOnly;
          final lot = values.whereType<QualityLotSummary>().firstOrNull ??
              const QualityLotSummary();
          final history = values.whereType<List<QualityInspectionReadOnly>>().firstOrNull ??
              const <QualityInspectionReadOnly>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _PageTitle(
                code: detail.lotCode ?? lot.text('lotCode') ?? 'Lô chưa xác định',
                passed: detail.passedInspection,
              ),
              _SectionCard(
                title: 'Thông tin lô',
                children: [
                  _Field('Mã lô', detail.lotCode ?? lot.text('lotCode')),
                  _Field('Loại hàng', lot.text('productVariantName') ?? lot.text('lotType')),
                  _Field('Vị trí', lot.text('locationCode') ?? lot.text('warehouseName')),
                  _Field('Tổng tồn của lô', _kg(lot.values['remainingWeightKg'] ?? lot.values['initialWeightKg'])),
                  _Field('Số lượng ảnh hưởng', _kg(detail.affectedWeightKg)),
                ],
              ),
              _SectionCard(
                title: 'Kết quả kiểm định',
                children: [
                  _Field('Phạm vi xử lý', _dash(detail.handling)),
                  _Field('Độ ẩm', _percent(detail.moisturePercent)),
                  _Field('Tạp chất', _percent(detail.impurityPercent)),
                  _Field('Mốc / Sâu mọt', '${_dash(detail.moldLevel)} / ${_dash(detail.pestLevel)}'),
                  _Field('Đóng gói', _dash(detail.packagingStatus)),
                  _Field('Rủi ro chính', _dash(detail.note)),
                  _Field('Mức độ', _dash(lot.text('severity'))),
                  _Field('Trạng thái', _status(detail.passedInspection)),
                  _Field('Hướng xử lý', _dash(detail.handling)),
                  _Field('Ghi chú', _dash(detail.note)),
                ],
              ),
              _SectionCard(
                title: 'Thông tin thực hiện',
                children: [
                  _Field('Người kiểm', detail.inspectorName),
                  _Field('Thời gian', _date(detail.inspectedAt)),
                  _Field('Ngày tạo', _date(detail.createdDate)),
                  _Field('Cập nhật', _date(detail.lastModifiedDate)),
                ],
              ),
              if (history.isNotEmpty)
                _SectionCard(
                  title: 'Lịch sử kiểm định',
                  children: [
                    for (final record in history)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          record.passedInspection == true
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_rounded,
                          color: record.passedInspection == true
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                        title: Text(
                          '${record.lotCode ?? 'Lô chưa xác định'} • ${_date(record.inspectedAt)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(_status(record.passedInspection)),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.code, required this.passed});
  final String code;
  final bool? passed;

  @override
  Widget build(BuildContext context) {
    final color = passed == true
        ? AppColors.success
        : passed == false
            ? AppColors.danger
            : AppColors.warning;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(code, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            _StatusBadge(label: _status(passed), color: color),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const Divider(height: 18),
              ...children,
            ],
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 142, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            Expanded(child: Text(_dash(value), style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

String _dash(String? value) => value == null || value.trim().isEmpty ? '—' : value;
String _status(bool? passed) => passed == true ? 'Đạt' : passed == false ? 'Không đạt' : 'Chờ kiểm định';
String _percent(double? value) => value == null ? '—' : '$value%';
String _kg(Object? value) => value == null ? '—' : '$value kg';
String _date(DateTime? value) => value == null ? '—' : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
