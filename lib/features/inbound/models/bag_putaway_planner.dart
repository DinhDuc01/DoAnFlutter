import '../../../core/utils/format.dart';
import 'inbound_order.dart';

/// Logic thao tác phương án xếp bao — port đúng bản web `inbound-putaway`.
///
/// Quy ước LIFO: mảng `bags` của một cột giữ thứ tự vật lý ĐÁY → ĐỈNH đúng như
/// backend nhận. Giao diện hiển thị ngược lại (đỉnh → đáy) để STT ưu tiên 1 nằm
/// trên cùng: bao nhập sau nằm ở đỉnh và được lấy ra trước.

/// Một nhóm bao liên tiếp cùng khối lượng trong một cột.
class BagDisplayGroup {
  const BagDisplayGroup({
    required this.key,
    required this.weightKg,
    required this.bags,
    required this.priorityStart,
    required this.priorityEnd,
    required this.isStandardWeight,
  });

  final String key;
  final double weightKg;
  final List<BagPutawayBag> bags;
  final int priorityStart;
  final int priorityEnd;
  final bool isStandardWeight;

  int get count => bags.length;

  List<int> get bagIds => [for (final bag in bags) bag.id];

  String get priorityLabel =>
      priorityStart == priorityEnd ? '$priorityStart' : '$priorityStart–$priorityEnd';

  String get title => count > 1
      ? '$count bao × ${formatKg(weightKg)}'
      : 'Bao #${bags.first.bagNo} · ${formatKg(weightKg)}';

  String get kind {
    if (count > 1) {
      return isStandardWeight
          ? 'Nhóm chuẩn · liên tục'
          : 'Nhóm cùng khối lượng · liên tục';
    }
    return isStandardWeight ? 'Bao chuẩn' : 'Bao lẻ';
  }
}

/// Kết quả một thao tác sửa phương án: [plan] mới và [error] nếu không hợp lệ.
class BagPlanMoveResult {
  const BagPlanMoveResult(this.plan, {this.error});

  final BagPutawayPlan plan;
  final String? error;

  bool get isChanged => error == null;
}

class BagPutawayPlanner {
  const BagPutawayPlanner._();

  /// Khối lượng bao "chuẩn" = khối lượng xuất hiện nhiều nhất trong phương án.
  static double standardBagWeight(BagPutawayPlan plan) {
    final counts = <String, ({double weight, int count})>{};
    for (final column in plan.columns) {
      for (final bag in column.bags) {
        final key = bag.weightKg.toStringAsFixed(3);
        final current = counts[key];
        counts[key] = (weight: bag.weightKg, count: (current?.count ?? 0) + 1);
      }
    }
    if (counts.isEmpty) return 0;
    final values = counts.values.toList()
      ..sort((a, b) => b.count != a.count
          ? b.count.compareTo(a.count)
          : b.weight.compareTo(a.weight));
    return values.first.weight;
  }

  /// Gom các bao LIÊN TIẾP cùng khối lượng (không gom rời rạc để giữ đúng stack).
  static List<BagDisplayGroup> columnGroups(
    BagPutawayColumn column,
    BagPutawayPlan plan,
  ) {
    if (column.bags.isEmpty) return const <BagDisplayGroup>[];
    final standard = standardBagWeight(plan);
    final groups = <BagDisplayGroup>[];
    var run = <BagPutawayBag>[];

    void flush() {
      if (run.isEmpty) return;
      final bottomIndex = column.bags.indexWhere((bag) => bag.id == run.first.id);
      final topIndex = column.bags.indexWhere((bag) => bag.id == run.last.id);
      groups.add(
        BagDisplayGroup(
          key: '${column.locationId}:${run.first.id}:${run.last.id}',
          weightKg: run.first.weightKg,
          bags: List<BagPutawayBag>.from(run),
          priorityStart: column.bags.length - topIndex,
          priorityEnd: column.bags.length - bottomIndex,
          isStandardWeight: (run.first.weightKg - standard).abs() < 0.001,
        ),
      );
      run = <BagPutawayBag>[];
    }

    for (final bag in column.bags) {
      if (run.isNotEmpty && (run.first.weightKg - bag.weightKg).abs() >= 0.001) {
        flush();
      }
      run.add(bag);
    }
    flush();

    // Backend nhận đáy → đỉnh; UI hiển thị đỉnh → đáy.
    return groups.reversed.toList();
  }

  /// Đưa một nhóm bao lên đỉnh hoặc xuống đáy trong CÙNG cột.
  static BagPlanMoveResult moveGroupOrder(
    BagPutawayPlan plan,
    int locationId,
    List<int> bagIds, {
    required bool toTop,
  }) {
    final ids = bagIds.toSet();
    if (ids.isEmpty) return BagPlanMoveResult(plan);
    final index = plan.columns.indexWhere((c) => c.locationId == locationId);
    if (index < 0) return BagPlanMoveResult(plan);

    final column = plan.columns[index];
    final moving = column.bags.where((bag) => ids.contains(bag.id)).toList();
    final rest = column.bags.where((bag) => !ids.contains(bag.id)).toList();
    if (moving.length != ids.length) return BagPlanMoveResult(plan);

    final reordered = toTop ? [...rest, ...moving] : [...moving, ...rest];
    final columns = List<BagPutawayColumn>.from(plan.columns);
    columns[index] = column.copyWith(bags: reordered);
    return BagPlanMoveResult(plan.copyWith(columns: columns));
  }

  /// Chuyển một nhóm bao sang cột khác (kể cả cột chưa mở, lấy từ ứng viên).
  static BagPlanMoveResult moveGroupToLocation(
    BagPutawayPlan plan,
    List<int> bagIds,
    int targetLocationId,
  ) {
    final ids = bagIds.toSet();
    if (ids.isEmpty) return BagPlanMoveResult(plan);

    final sourceIndex =
        plan.columns.indexWhere((c) => c.bags.any((bag) => ids.contains(bag.id)));
    if (sourceIndex < 0) return BagPlanMoveResult(plan);
    final source = plan.columns[sourceIndex];
    if (source.locationId == targetLocationId) return BagPlanMoveResult(plan);

    final moving = source.bags.where((bag) => ids.contains(bag.id)).toList();
    if (moving.length != ids.length) return BagPlanMoveResult(plan);
    final movingWeight =
        moving.fold<double>(0, (sum, bag) => sum + bag.weightKg);

    var columns = List<BagPutawayColumn>.from(plan.columns);
    var targetIndex = columns.indexWhere((c) => c.locationId == targetLocationId);
    if (targetIndex < 0) {
      final candidate = plan.candidateLocations
          .where((item) => item.locationId == targetLocationId)
          .firstOrNull;
      if (candidate == null) return BagPlanMoveResult(plan);
      columns.add(
        BagPutawayColumn(
          locationId: candidate.locationId,
          slotCode: candidate.slotCode,
          bags: const <BagPutawayBag>[],
          totalKg: 0,
          capacityRemainAfter: candidate.capacityAvailableKg,
          reason: candidate.reason,
        ),
      );
      targetIndex = columns.length - 1;
    }

    final target = columns[targetIndex];
    if (target.capacityRemainAfter + 0.001 < movingWeight) {
      return BagPlanMoveResult(
        plan,
        error: 'Cột ${target.slotCode} không đủ sức chứa cho '
            '${moving.length} bao (${formatKg(movingWeight)}).',
      );
    }

    final sourceBags = source.bags.where((bag) => !ids.contains(bag.id)).toList();
    columns[sourceIndex] = source.copyWith(
      bags: sourceBags,
      totalKg: source.totalKg - movingWeight,
      capacityRemainAfter: source.capacityRemainAfter + movingWeight,
    );
    // Nhóm chuyển sang cột khác được xếp tiếp lên đỉnh của cột đích (LIFO).
    columns[targetIndex] = target.copyWith(
      bags: [...target.bags, ...moving],
      totalKg: target.totalKg + movingWeight,
      capacityRemainAfter: target.capacityRemainAfter - movingWeight,
    );

    columns = rankColumns(
      columns.where((column) => column.bags.isNotEmpty).toList(),
      plan,
    );
    return BagPlanMoveResult(plan.copyWith(columns: columns));
  }

  /// Sắp xếp cột theo: cùng loại hàng → ưu tiên vị trí → còn ít chỗ hơn.
  static List<BagPutawayColumn> rankColumns(
    List<BagPutawayColumn> columns,
    BagPutawayPlan plan,
  ) {
    BagPutawayCandidate? candidateOf(int locationId) => plan.candidateLocations
        .where((item) => item.locationId == locationId)
        .firstOrNull;

    final sorted = List<BagPutawayColumn>.from(columns)
      ..sort((a, b) {
        final ca = candidateOf(a.locationId);
        final cb = candidateOf(b.locationId);
        final sameVariant = (cb?.containsSameVariant == true ? 1 : 0) -
            (ca?.containsSameVariant == true ? 1 : 0);
        if (sameVariant != 0) return sameVariant;
        final priority = (cb?.priority ?? 0) - (ca?.priority ?? 0);
        if (priority != 0) return priority;
        final capacity = a.capacityRemainAfter.compareTo(b.capacityRemainAfter);
        if (capacity != 0) return capacity;
        return a.locationId - b.locationId;
      });
    return [
      for (var index = 0; index < sorted.length; index++)
        sorted[index].copyWith(priorityRank: index + 1),
    ];
  }

  /// Xếp danh sách gợi ý theo đúng thứ tự ứng viên của phương án xếp bao.
  static List<PutawaySuggestion> orderSuggestionsByPlan(
    List<PutawaySuggestion> suggestions,
    BagPutawayPlan? plan,
  ) {
    if (plan == null || plan.candidateLocations.isEmpty) return suggestions;
    final rank = <int, int>{
      for (var index = 0; index < plan.candidateLocations.length; index++)
        plan.candidateLocations[index].locationId: index,
    };
    final ordered = List<PutawaySuggestion>.from(suggestions)
      ..sort((a, b) => (rank[a.locationId] ?? 1 << 30)
          .compareTo(rank[b.locationId] ?? 1 << 30));
    return ordered;
  }
}
