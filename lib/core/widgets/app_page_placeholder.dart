import 'package:flutter/material.dart';

/// Widget đại diện cho một trang trống tạm thời (Placeholder Page) để hiển thị khi chức năng chưa được hoàn thiện.
class AppPagePlaceholder extends StatelessWidget {
  const AppPagePlaceholder({
    required this.title,
    required this.description,
    super.key,
  });

  /// Tiêu đề của trang hiển thị trên AppBar và đầu trang.
  final String title;

  /// Mô tả chi tiết hoặc thông tin của trang.
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề của trang với kiểu chữ in đậm cỡ headlineSmall
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8), // Khoảng cách giữa tiêu đề và mô tả
            // Văn bản mô tả
            Text(description),
          ],
        ),
      ),
    );
  }
}
