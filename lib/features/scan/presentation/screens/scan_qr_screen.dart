import 'package:flutter/material.dart';

import '../widgets/scan_action_panel.dart';
import '../widgets/scan_bottom_bar.dart';
import '../widgets/scan_camera_preview.dart';
import '../widgets/scan_header.dart';

class ScanQrScreen extends StatelessWidget {
  const ScanQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            ScanHeader(),
            Expanded(child: ScanCameraPreview()),
            ScanActionPanel(),
          ],
        ),
      ),
      bottomNavigationBar: ScanBottomBar(),
    );
  }
}
