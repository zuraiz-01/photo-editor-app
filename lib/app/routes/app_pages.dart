import 'package:get/get.dart';

import '../modules/editor/bindings/editor_binding.dart';
import '../modules/editor/views/editor_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(name: Routes.home, page: HomeView.new, binding: HomeBinding()),
    GetPage(
      name: Routes.editor,
      page: EditorView.new,
      binding: EditorBinding(),
    ),
  ];
}
