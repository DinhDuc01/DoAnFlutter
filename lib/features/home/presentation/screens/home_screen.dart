import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const modules = [
      _HomeModule('Nhap kho', Icons.call_received, AppRoutes.inbound),
      _HomeModule('Xuat kho', Icons.call_made, AppRoutes.outbound),
      _HomeModule('Kiem kho', Icons.fact_check_outlined, AppRoutes.inventory),
      _HomeModule('Quet QR', Icons.qr_code_scanner, AppRoutes.scanQr),
      _HomeModule('Bao cao', Icons.bar_chart, AppRoutes.reports),
      _HomeModule('Thong bao', Icons.notifications_outlined, AppRoutes.notifications),
      _HomeModule('Tai khoan', Icons.person_outline, AppRoutes.account),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chu'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: modules.length,
        itemBuilder: (context, index) {
          final module = modules[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pushNamed(module.route),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(module.icon, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      module.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeModule {
  const _HomeModule(this.title, this.icon, this.route);

  final String title;
  final IconData icon;
  final String route;
}
