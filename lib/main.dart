import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:monkread/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local persistence
  await Hive.initFlutter();

  runApp(
    const ProviderScope(
      child: MonkReadApp(),
    ),
  );
}
