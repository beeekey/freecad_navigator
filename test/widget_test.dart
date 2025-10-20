import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:freecad_navigator/app.dart';
import 'package:freecad_navigator/core/db.dart';

void main() {
  testWidgets('App renders title bar', (tester) async {
    sqfliteFfiInit();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseFactoryProvider.overrideWithValue(databaseFactoryFfi),
        ],
        child: const FreecadExplorerApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('FreeCAD Navigator'), findsOneWidget);
  });
}
