import 'dart:async';

import 'package:flutter/material.dart';

import 'realtime_service.dart';

/// Widget tải dữ liệu có realtime + trải nghiệm "chỉ loading lần đầu".
///
/// - Lần đầu vào màn: hiện [loadingBuilder] (mặc định vòng xoay).
/// - Các lần tải lại sau (do realtime báo thay đổi, do pull-to-refresh, hoặc gọi
///   [RealtimeDataController.reload]): KHÔNG hiện loading — giữ dữ liệu cũ trên
///   màn và render lại im lặng khi có dữ liệu mới, tăng UX.
/// - Tự tải lại khi [RealtimeService] báo có entity trong [entities] thay đổi.
///   [entities] rỗng nghĩa là tải lại với BẤT KỲ thay đổi nào.
class RealtimeDataView<T> extends StatefulWidget {
  const RealtimeDataView({
    required this.loader,
    required this.builder,
    this.entities = const <String>{},
    this.loadingBuilder,
    this.errorBuilder,
    this.enablePullToRefresh = true,
    this.controller,
    super.key,
  });

  /// Hàm nạp dữ liệu (gọi API).
  final Future<T> Function() loader;

  /// Dựng UI khi đã có dữ liệu.
  final Widget Function(BuildContext context, T data) builder;

  /// Tên các entity khiến màn này cần tải lại (khớp tên bên server). Rỗng =
  /// tải lại với mọi thay đổi.
  final Set<String> entities;

  /// UI khi đang tải lần đầu.
  final WidgetBuilder? loadingBuilder;

  /// UI khi lỗi lần đầu (chưa có dữ liệu). [retry] gọi tải lại.
  final Widget Function(BuildContext context, Object error, VoidCallback retry)?
      errorBuilder;

  /// Cho phép kéo để làm mới.
  final bool enablePullToRefresh;

  /// Bộ điều khiển để tải lại từ bên ngoài (tuỳ chọn).
  final RealtimeDataController? controller;

  @override
  State<RealtimeDataView<T>> createState() => _RealtimeDataViewState<T>();
}

/// Cho phép màn cha yêu cầu [RealtimeDataView] tải lại (im lặng).
class RealtimeDataController {
  VoidCallback? _reload;

  void reload() => _reload?.call();
}

class _RealtimeDataViewState<T> extends State<RealtimeDataView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;
  int _generation = 0;
  StreamSubscription<Set<String>>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    widget.controller?._reload = () => _load(showLoading: false);
    _realtimeSub =
        RealtimeService.instance.onEntitiesChanged.listen(_onEntitiesChanged);
    // Lần tải đầu: _loading đã mặc định true nên KHÔNG gọi setState trong
    // initState (tránh lỗi setState-during-build); UI hiện loading ngay.
    _load(showLoading: false);
  }

  @override
  void dispose() {
    if (widget.controller?._reload != null) widget.controller!._reload = null;
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _onEntitiesChanged(Set<String> changed) {
    if (!mounted) return;
    final relevant = widget.entities.isEmpty ||
        changed.any(widget.entities.contains);
    if (relevant) _load(showLoading: false);
  }

  Future<void> _load({required bool showLoading}) async {
    final generation = ++_generation;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await widget.loader();
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      // Chỉ hiện lỗi khi CHƯA có dữ liệu. Nếu đã có dữ liệu cũ thì giữ nguyên
      // (reload im lặng thất bại không nên phá màn đang xem).
      if (_data == null) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return widget.loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _data == null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(
          context,
          _error!,
          () => _load(showLoading: true),
        );
      }
      return _DefaultError(
        error: _error!,
        onRetry: () => _load(showLoading: true),
      );
    }

    final content = widget.builder(context, _data as T);
    if (!widget.enablePullToRefresh) return content;

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: content,
    );
  }
}

class _DefaultError extends StatelessWidget {
  const _DefaultError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Không tải được dữ liệu',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
