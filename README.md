# Photo Editor

Lightweight Flutter photo editor with filters, text, stickers, crop, and quick export.

## Features
- Image intake: pick from gallery or capture via camera.
- Crop: native `image_cropper` UI.
- Filters: multiple color-matrix presets with intensity slider and live previews.
- Text overlay: add/update/delete, color + size, drag to move.
- Stickers: emoji stickers with move/scale/rotate, delete, bring-to-front.
- Save/export: renders current preview to PNG and saves to gallery (handles permissions).
- Replace image: swap the current photo from gallery or camera without leaving the editor.
- Dark neon UI built with GetX navigation and state management.

## Build & Run
```
flutter pub get
flutter run
```

## Release prep
- Android: set your keystore in `android/key.properties` and ensure `applicationId` is correct in `android/app/build.gradle.kts`.
- iOS: align bundle identifier in Xcode if needed.
- Generate assets (already configured): `flutter pub run flutter_launcher_icons` and `flutter pub run flutter_native_splash:create`.

## Permissions
- Android: Camera, Photos/Storage for pick/save.
- iOS: Camera, Photo Library read/write (usage descriptions in `ios/Runner/Info.plist`).

## TODO / Roadmap
- [x] Adjustment panel: brightness, contrast, exposure, vibrance, temperature sliders.
- [x] Blur & vignette: radial vignette and selective blur for focus.
- [x] Brush/doodle: freehand draw with size/color/opacity; undo/redo for strokes; eraser mode and stroke delete.
- [x] Shapes & frames: rectangles/circles/arrows plus simple borders/frames; frame presets with color/width/radius.
- [x] User presets: save/apply custom filter combos; apply/delete via chips.
- [x] Background removal: tunable color-key removal with threshold slider.
- [x] Perspective tools: straighten, rotate, flip, and tilt/skew.
- [x] Layers panel: reorder/hide/lock text and stickers; stroke list with delete.
- [x] Templates: common social sizes with safe-area guides.
- [x] Export options: quality slider, PNG/JPEG toggle, share sheet, resize presets.
- [x] Localization & themes: light/dark toggle.
- [ ] Advanced background removal (better matting/edge quality).
- [ ] More frame styles/patterns and per-platform safe-area presets.
- [ ] Export: aspect + height presets, batch outputs.
