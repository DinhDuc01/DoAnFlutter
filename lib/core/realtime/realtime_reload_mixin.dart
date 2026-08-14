import 'dart:async';

import 'package:flutter/widgets.dart';

import 'realtime_service.dart';

/// Gắn realtime cho một màn tự quản lý state (StatefulWidget dùng setState).
///
/// Dùng khi màn KHÔNG dựng bằng [RealtimeDataView]: chỉ cần khai báo
/// [realtimeEntities] và [onRealtimeChanged], mixin lo phần đăng ký/hủy lắng
/// nghe [RealtimeService].
///
/// ```dart
/// class _MyScreenState extends State<MyScreen> with RealtimeReloadMixin {
///   @override
///   Set<String> get realtimeEntities => const {'SalesOrder'};
///
///   @override
///   void onRealtimeChanged() => _load(showLoading: false);
/// }
/// ```
///
/// Quy ước: [onRealtimeChanged] phải tải lại IM LẶNG (không bật cờ loading, không
/// nhảy về trang 1) để dữ liệu người dùng đang xem không bị giật.
mixin RealtimeReloadMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<Set<String>>? _realtimeSubscription;

  /// Tên các entity khiến màn này cần tải lại (khớp tên class entity ở backend).
  /// Trả về tập rỗng nghĩa là tải lại với BẤT KỲ thay đổi nào.
  Set<String> get realtimeEntities;

  /// Được gọi (đã debounce ở [RealtimeService]) khi có entity quan tâm thay đổi.
  void onRealtimeChanged();

  @override
  void initState() {
    super.initState();
    _realtimeSubscription =
        RealtimeService.instance.onEntitiesChanged.listen(_handleChanged);
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    super.dispose();
  }

  void _handleChanged(Set<String> changed) {
    if (!mounted) return;
    final watched = realtimeEntities;
    if (watched.isNotEmpty && !changed.any(watched.contains)) return;
    onRealtimeChanged();
  }
}
