import 'package:flutter/material.dart';

class StockTakeDetailScreen extends StatefulWidget {
  const StockTakeDetailScreen({super.key});

  @override
  State<StockTakeDetailScreen> createState() => _StockTakeDetailScreenState();
}

class _StockTakeDetailScreenState extends State<StockTakeDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Stock Take Detail Screen'),
      ),
    );
  }
}
