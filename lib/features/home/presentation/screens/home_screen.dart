import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/home_content.dart';
import '../widgets/home_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              HomeHeader(),
              HomeContent(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: HomeBottomNav(),
    );
  }
}
