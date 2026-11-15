# ADM - Browser & Download Manager

ADM is an Android browser and download manager built with Flutter UI and a native Kotlin WebView host.

## Current foundation
- Chromium-based rendering through Android System WebView.
- Google Search as the default search provider.
- Address/search bar, multiple browser tabs, back/forward/reload and home actions.
- Download interception from WebView and enqueue through Android DownloadManager.
- Transfer list with live status, byte counts, and progress where Android reports a total size.
- Bookmarks and browsing history stored locally on the device.
- Cyber-gaming dark interface, with Portuguese UI labels.
- HTTPS-only network policy for app traffic; file/content access is disabled in WebView.

## Generate the Android host project

The Android host sources are stored in android-template/. Run:

    flutter pub get
    bash tool/bootstrap_android.sh
    flutter run

The script uses the installed Flutter SDK to generate the matching Android Gradle wrapper and project files, then installs ADM's Kotlin host and Android manifest.

## Build an APK

    flutter pub get
    bash tool/bootstrap_android.sh
    flutter analyze
    flutter build apk --release

The APK is generated at build/app/outputs/flutter-apk/app-release.apk.

A GitHub Actions workflow also builds the APK on pushes and manual dispatch, then uploads it as a workflow artifact.

## Download behaviour

The first implementation uses Android's system DownloadManager. It supports background transfer and system notifications, but Android DownloadManager does not expose universal pause/resume or segmented-download controls. Those advanced controls require a separate native transfer engine and server support for HTTP Range requests. ADM must not show pause/resume as available unless the server and transfer engine confirm support.

## Browser engine

ADM does not bundle the proprietary Google Chrome app. It hosts Android System WebView, which is based on Chromium. Google Search is configured separately as the default search provider.

## Minimum environment

- Flutter stable channel with Android support.
- Android SDK and Java toolchain required by the installed Flutter version.
- Android device or emulator with Android System WebView installed and updated.
