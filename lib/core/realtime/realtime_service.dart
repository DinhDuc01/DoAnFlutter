import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../features/auth/data/auth_session_store.dart';
import '../config/api_config.dart';

/// Realtime "invalidate-on-change" giống web: server (SignalR hub
/// `/hubs/data-change`) chỉ báo "entity X vừa đổi" (sự kiện `EntityChanged` kèm
/// danh sách tên entity), client tự tải lại dữ liệu màn đang mở.
///
/// Dùng: gọi [start] sau khi đăng nhập, [stop] khi đăng xuất. Các màn lắng nghe
/// [onEntitiesChanged] (đã gộp/deboucne) để reload im lặng.
class RealtimeService {
  RealtimeService._();

  /// Thể hiện singleton dùng chung.
  static final RealtimeService instance = RealtimeService._();

  HubConnection? _connection;
  bool _starting = false;

  final StreamController<Set<String>> _controller =
      StreamController<Set<String>>.broadcast();

  final Set<String> _pending = <String>{};
  Timer? _debounce;

  /// Phát tập tên entity vừa thay đổi (đã gộp nhiều sự kiện liên tiếp).
  Stream<Set<String>> get onEntitiesChanged => _controller.stream;

  /// Mở kết nối realtime (idempotent). An toàn khi gọi lại nhiều lần.
  Future<void> start() async {
    if (_connection != null || _starting) return;
    _starting = true;

    // baseUrl là gốc host (ApiClient tự thêm /api/v1). Hub nằm ở gốc host.
    final host = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/v\d+/?$'), '');
    final hubUrl = '$host/hubs/data-change';

    try {
      final connection = HubConnectionBuilder()
          .withUrl(
            hubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async =>
                  AuthSessionStore.current?.accessToken ?? '',
            ),
          )
          .withAutomaticReconnect()
          .build();

      connection.on('EntityChanged', _handleEntityChanged);

      await connection.start();
      _connection = connection;
    } catch (error) {
      // Không kết nối được thì app vẫn chạy bình thường (chỉ mất realtime).
      debugPrint('[Realtime] Kết nối hub thất bại: $error');
      _connection = null;
    } finally {
      _starting = false;
    }
  }

  /// Đóng kết nối (gọi khi đăng xuất).
  Future<void> stop() async {
    _debounce?.cancel();
    _debounce = null;
    _pending.clear();
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      try {
        await connection.stop();
      } catch (_) {
        // Bỏ qua lỗi đóng.
      }
    }
  }

  void _handleEntityChanged(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;
    final names = _extractNames(arguments.first);
    if (names.isEmpty) return;

    _pending.addAll(names);

    // Gom nhiều sự kiện liên tiếp (VD import nhiều dòng) -> chỉ phát 1 lần.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _flush);
  }

  Set<String> _extractNames(Object? raw) {
    final result = <String>{};
    if (raw is Iterable) {
      for (final item in raw) {
        final name = item?.toString().trim();
        if (name != null && name.isNotEmpty) result.add(name);
      }
    } else if (raw is String && raw.trim().isNotEmpty) {
      result.add(raw.trim());
    }
    return result;
  }

  void _flush() {
    _debounce = null;
    if (_pending.isEmpty) return;
    final snapshot = Set<String>.from(_pending);
    _pending.clear();
    if (!_controller.isClosed) _controller.add(snapshot);
  }
}
