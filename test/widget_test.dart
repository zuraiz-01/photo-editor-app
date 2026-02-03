import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_editor/main.dart';
import 'package:photo_editor/app/modules/editor/views/editor_view.dart';
import 'package:photo_editor/app/modules/editor/controllers/editor_controller.dart';
import 'package:photo_editor/app/theme/theme_controller.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('Home screen renders primary actions', (WidgetTester tester) async {
    Get.put(ThemeController());
    await tester.pumpWidget(const MyApp());

    expect(find.text('Select an image to start editing'), findsOneWidget);
    expect(find.text('Pick from Gallery'), findsOneWidget);
    expect(find.text('Capture from Camera'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing); // ensure counter UI removed
  });

  testWidgets('Editor shows empty state when no image', (WidgetTester tester) async {
    Get.reset();
    Get.put(ThemeController());
    Get.put(EditorController());
    await tester.pumpWidget(
      const GetMaterialApp(
        home: EditorView(),
      ),
    );

    expect(find.text('No image selected'), findsOneWidget);
    expect(find.byTooltip('Replace photo'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
