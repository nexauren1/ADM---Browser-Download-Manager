# ADM - Browser & Download Manager

ADM is an Android browser and download manager under the Nexauren identity.

## Interface
Dedicated download-manager structure: queue, completed downloads, link editor, category-based settings and browser. The visual identity uses Nexauren dark surfaces, electric cyan and violet.

## Implemented foundation
- Flutter interface with queue and completed tabs.
- Add-download editor with URL validation, clipboard paste and optional filename.
- Native Android DownloadManager integration for HTTP/HTTPS transfers.
- Download state, byte counts and system-reported progress; completed files open through Android.
- Wi-Fi-only preference for new downloads.
- Browser hosted by Android System WebView (Chromium), Google Search, navigation controls and download interception.
- Settings categories that identify features not yet available in the current engine.
- GitHub Actions workflow to generate the Android host and build a release APK.

## Build
    flutter pub get
    bash tool/bootstrap_android.sh
    flutter analyze
    flutter build apk --release

APK output: build/app/outputs/flutter-apk/app-release.apk

## Download engine limits
The initial version delegates transfers to Android DownloadManager. It supports background transfers and system notifications, but does not expose universal per-file pause/resume, segmented downloads, custom speed limits, BitTorrent or scheduling. These need a dedicated engine and, for resumable/segmented HTTP transfers, server support for HTTP Range requests. The interface labels these modules as not active rather than showing non-functional controls.

## Browser engine
ADM hosts Android System WebView, which is based on Chromium. It is not the complete Google Chrome app. Google Search is configured as the default search provider.

## Android application ID
com.nexauren.adm
