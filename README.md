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
