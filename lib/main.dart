import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'core/db.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  runApp(
    ProviderScope(
      overrides: [
        databaseFactoryProvider.overrideWithValue(databaseFactoryFfi),
      ],
      child: const FreecadExplorerApp(),
    ),
  );
}
