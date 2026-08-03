import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/character/data/character_appearance_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CharacterAppearanceController.instance.load();
  runApp(const StockLiteApp());
}
