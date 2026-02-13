# MonkRead

A local-first PDF Reader built with **Flutter**, following **Clean Architecture** and **Riverpod** state management.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.0+)
- Android Studio / Xcode for platform toolchains
- An Android emulator or physical device

## Getting Started

### 1. Install Flutter SDK

Follow the [official guide](https://docs.flutter.dev/get-started/install/windows) to install Flutter on Windows.

After installation, verify:

```bash
flutter doctor
```

### 2. Scaffold Platform Files

Since this project was created without the Flutter CLI, you need to generate the platform-specific folders (android/, ios/, web/, test/):

```bash
cd "c:\Users\dekor\OneDrive\Masaüstü\Pdf okuyucu"
flutter create --org com.monkread --project-name monkread .
```

> **Note:** `flutter create .` will generate missing files (android/, ios/, test/, etc.) **without overwriting** existing files like `lib/main.dart` or `pubspec.yaml`.

### 3. Configure Android Permissions

After `flutter create`, open `android/app/src/main/AndroidManifest.xml` and add the following permissions inside the `<manifest>` tag (before `<application>`):

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

Also add `android:requestLegacyExternalStorage="true"` to the `<application>` tag for Android 10 compatibility:

```xml
<application
    android:requestLegacyExternalStorage="true"
    ...>
```

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Run the App

```bash
flutter run
```

## Architecture

```
lib/
├── main.dart                              # Entry point (ProviderScope)
├── app.dart                               # MaterialApp.router
├── core/
│   ├── errors/failures.dart               # Sealed failure types
│   ├── theme/app_theme.dart               # Material 3 themes
│   └── constants/app_constants.dart       # Route names, extensions
├── data/
│   └── repositories/file_repository_impl.dart  # file_picker + permission_handler
├── domain/
│   ├── entities/pdf_document.dart          # Pure domain entity
│   └── repositories/file_repository.dart   # Abstract contract
└── presentation/
    ├── providers/
    │   ├── file_provider.dart             # PdfPickNotifier + states
    │   └── permission_provider.dart       # Storage permission check
    ├── router/app_router.dart             # GoRouter config
    ├── screens/
    │   ├── home_screen.dart               # Landing page + FAB
    │   └── reader_screen.dart             # PDF rendering
    └── widgets/error_dialog.dart          # Reusable error dialog
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `go_router` | Declarative navigation |
| `permission_handler` | Runtime permissions |
| `file_picker` | Native file picker |
| `flutter_pdfview` | PDF rendering |
