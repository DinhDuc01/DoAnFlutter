import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/realtime/realtime_reload_mixin.dart';
import 'package:stocklite/core/realtime/realtime_service.dart';

/// Màn thử: đếm số lần được yêu cầu tải lại theo tín hiệu realtime.
class _ProbeScreen extends StatefulWidget {
  const _ProbeScreen({required this.entities, required this.onReload});

  final Set<String> entities;
  final VoidCallback onReload;

  @override
  State<_ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<_ProbeScreen> with RealtimeReloadMixin {
  @override
  Set<String> get realtimeEntities => widget.entities;

  @override
  void onRealtimeChanged() => widget.onReload();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  Future<void> pumpProbe(
    WidgetTester tester, {
    required Set<String> entities,
    required VoidCallback onReload,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _ProbeScreen(entities: entities, onReload: onReload),
      ),
    );
  }

  testWidgets('tải lại khi entity quan tâm thay đổi', (tester) async {
    var reloads = 0;
    await pumpProbe(
      tester,
      entities: const {'SalesOrder', 'OutboundOrder'},
      onReload: () => reloads++,
    );

    RealtimeService.instance.debugEmit({'OutboundOrder'});
    await tester.pump();

    expect(reloads, 1);
  });

  testWidgets('bỏ qua entity không liên quan', (tester) async {
    var reloads = 0;
    await pumpProbe(
      tester,
      entities: const {'SalesOrder'},
      onReload: () => reloads++,
    );

    RealtimeService.instance.debugEmit({'Notification'});
    await tester.pump();

    expect(reloads, 0);
  });

  testWidgets('tập entity rỗng nghĩa là tải lại với mọi thay đổi',
      (tester) async {
    var reloads = 0;
    await pumpProbe(
      tester,
      entities: const <String>{},
      onReload: () => reloads++,
    );

    RealtimeService.instance.debugEmit({'BatKyEntityNao'});
    await tester.pump();

    expect(reloads, 1);
  });

  testWidgets('hủy lắng nghe khi màn bị gỡ khỏi cây widget', (tester) async {
    var reloads = 0;
    await pumpProbe(
      tester,
      entities: const {'SalesOrder'},
      onReload: () => reloads++,
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    RealtimeService.instance.debugEmit({'SalesOrder'});
    await tester.pump();

    expect(reloads, 0);
  });
}
