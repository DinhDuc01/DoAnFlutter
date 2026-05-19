import 'package:flutter/material.dart';

import 'quick_action_grid.dart';
import 'recent_activity_card.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thao tác nhanh',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          QuickActionGrid(),
          SizedBox(height: 18),
          Text(
            'Hoạt động gần đây',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          RecentActivityCard(),
        ],
      ),
    );
  }
}
