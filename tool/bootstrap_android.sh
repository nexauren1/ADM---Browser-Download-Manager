#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK não encontrado. Instala Flutter stable." >&2
  exit 1
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
flutter create --platforms=android --project-name adm --org com.nexauren --no-pub "$TMP/adm"
cp -R "$TMP/adm/android" "$ROOT/android"
mkdir -p "$ROOT/android/app/src/main/kotlin/com/nexauren/adm"
cp "$ROOT/android-template/MainActivity.kt" "$ROOT/android/app/src/main/kotlin/com/nexauren/adm/MainActivity.kt"
cp "$ROOT/android-template/AndroidManifest.xml" "$ROOT/android/app/src/main/AndroidManifest.xml"
if [ -f "$ROOT/android/app/build.gradle.kts" ]; then
  sed -i 's/namespace = ".*"/namespace = "com.nexauren.adm"/' "$ROOT/android/app/build.gradle.kts"
  sed -i 's/applicationId = ".*"/applicationId = "com.nexauren.adm"/' "$ROOT/android/app/build.gradle.kts"
elif [ -f "$ROOT/android/app/build.gradle" ]; then
  sed -i 's/namespace .*/namespace "com.nexauren.adm"/' "$ROOT/android/app/build.gradle"
  sed -i 's/applicationId .*/applicationId "com.nexauren.adm"/' "$ROOT/android/app/build.gradle"
fi
echo "Projeto Android ADM preparado."
