import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../data/character_appearance_store.dart';
import '../../data/character_registry.dart';
import '../../models/character_appearance.dart';
import '../../models/character_manifest.dart';
import '../../runtime/character_renderer.dart';

class CharacterCustomizationScreen extends StatefulWidget {
  const CharacterCustomizationScreen({super.key});

  @override
  State<CharacterCustomizationScreen> createState() =>
      _CharacterCustomizationScreenState();
}

class _CharacterCustomizationScreenState
    extends State<CharacterCustomizationScreen> {
  late final Future<CharacterRegistry> _future = _load();
  CharacterAction _action = CharacterAction.idle;
  CharacterDirection _direction = CharacterDirection.front;

  Future<CharacterRegistry> _load() async {
    final registry = await CharacterRegistry.load();
    if (CharacterAppearanceController.instance.value == null) {
      await CharacterAppearanceController.instance.load(registry: registry);
    }
    return registry;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F4),
      appBar: AppBar(
        title: const Text('Ngoại hình nhân viên'),
        actions: [
          IconButton(
            tooltip: 'Character Lab',
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.characterLab,
            ),
            icon: const Icon(Icons.science_outlined),
          ),
        ],
      ),
      body: FutureBuilder<CharacterRegistry>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final registry = snapshot.data!;
          return ValueListenableBuilder<CharacterAppearance?>(
            valueListenable: CharacterAppearanceController.instance,
            builder: (context, appearance, _) {
              final current =
                  appearance ?? CharacterAppearance.defaults(registry.manifest);
              return _buildContent(registry, current);
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(
    CharacterRegistry registry,
    CharacterAppearance appearance,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          height: 310,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0C5C3A), Color(0xFF159447), Color(0xFFA7E8BD)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33166534),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned(
                left: 20,
                top: 18,
                child: Text(
                  'WORKER IDENTITY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontSize: 11,
                  ),
                ),
              ),
              Positioned.fill(
                child: CharacterStage(
                  registry: registry,
                  appearance: appearance,
                  action: _action,
                  direction: _direction,
                  padding: const EdgeInsets.fromLTRB(70, 48, 70, 8),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 14,
                child: _DirectionPad(
                  direction: _direction,
                  onChanged: (value) => setState(() => _direction = value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _SectionTitle(
          title: 'Chuyển động',
          subtitle: 'Mọi lớp dùng chung frame và playback clock.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CharacterAction.values.map((action) {
            return ChoiceChip(
              label: Text(_actionLabel(action)),
              selected: action == _action,
              onSelected: (_) => setState(() => _action = action),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Dáng người',
          subtitle: 'Đổi body mà không thay các slot tương thích.',
        ),
        ...registry.manifest.bodies.map((body) {
          return _SelectionTile(
            selected: appearance.bodyId == body.id,
            title: Text(body.label),
            subtitle: Text('${body.rig} · ${body.assetKey}'),
            onTap: () => CharacterAppearanceController.instance.update(
              appearance.copyWith(bodyId: body.id),
            ),
          );
        }),
        for (final slot in CharacterSlot.values) ...[
          const SizedBox(height: 14),
          _SectionTitle(
            title: _slotLabel(slot),
            subtitle: slot == CharacterSlot.outfit
                ? 'Layer bắt buộc; luôn có fallback an toàn.'
                : 'Layer tùy chọn; có thể tắt mà body vẫn hiển thị.',
          ),
          if (slot != CharacterSlot.outfit)
            _SelectionTile(
              selected: appearance.layers[slot] == null,
              title: const Text('Không sử dụng'),
              onTap: () => CharacterAppearanceController.instance.update(
                appearance.withLayer(slot, null),
              ),
            ),
          ...registry.optionsFor(slot, appearance.bodyId).map((layer) {
            return _SelectionTile(
              selected: appearance.layers[slot] == layer.id,
              leading: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: layer.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: layer.accentColor, width: 3),
                ),
              ),
              title: Text(layer.label),
              subtitle: Text('${layer.assetKey} · order ${layer.painterOrder}'),
              onTap: () => CharacterAppearanceController.instance.update(
                appearance.withLayer(slot, layer.id),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
  });

  final bool selected;
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: const Color(0xFFE1F7E9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? const Color(0xFF159447) : const Color(0xFF94A3B8),
      ),
      onTap: onTap,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DirectionPad extends StatelessWidget {
  const _DirectionPad({required this.direction, required this.onChanged});

  final CharacterDirection direction;
  final ValueChanged<CharacterDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC063B28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: CharacterDirection.values.map((value) {
            return IconButton(
              visualDensity: VisualDensity.compact,
              color:
                  value == direction ? const Color(0xFFF8D65A) : Colors.white70,
              onPressed: () => onChanged(value),
              icon: Icon(_directionIcon(value), size: 18),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}

String _actionLabel(CharacterAction action) => switch (action) {
      CharacterAction.idle => 'Đứng',
      CharacterAction.walk => 'Di chuyển',
      CharacterAction.scan => 'Quét mã',
      CharacterAction.lift => 'Nâng hàng',
      CharacterAction.celebrate => 'Hoàn tất',
    };

String _slotLabel(CharacterSlot slot) => switch (slot) {
      CharacterSlot.outfit => 'Đồng phục',
      CharacterSlot.headwear => 'Mũ',
      CharacterSlot.tool => 'Dụng cụ chính',
      CharacterSlot.offhand => 'Dụng cụ phụ',
      CharacterSlot.effect => 'Hiệu ứng',
    };

IconData _directionIcon(CharacterDirection direction) => switch (direction) {
      CharacterDirection.front => Icons.keyboard_arrow_down,
      CharacterDirection.right => Icons.keyboard_arrow_right,
      CharacterDirection.back => Icons.keyboard_arrow_up,
      CharacterDirection.left => Icons.keyboard_arrow_left,
    };
