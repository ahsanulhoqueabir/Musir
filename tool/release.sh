#!/usr/bin/env bash
# Release build: bump version in pubspec.yaml, build universal + split-per-ABI
# APKs, collect them under dist/<version>+<build>/ and validate everything.
#
# Usage: tool/release.sh [--bump patch|minor|major|build|none] [--skip-pub-get]
#   patch (default)  1.0.0+1 -> 1.0.1+2     build  1.0.0+1 -> 1.0.0+2
#   minor            1.0.0+1 -> 1.1.0+2     none   rebuild the current version
#   major            1.0.0+1 -> 2.0.0+2
# pubspec.yaml is restored if the build or validation fails, so a failed run
# never consumes a version.
set -euo pipefail
cd "$(dirname "$0")/.."

BUMP=patch; PUB_GET=1
while [ $# -gt 0 ]; do
  case "$1" in
    --bump) BUMP="${2:?--bump needs a value}"; shift 2 ;;
    --skip-pub-get) PUB_GET=0; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$BUMP" in patch|minor|major|build|none) ;; *) echo "bad --bump: $BUMP" >&2; exit 2 ;; esac

die() { echo "ERROR: $*" >&2; exit 1; }

# --- locate tools ---------------------------------------------------------
PROP_FILE=android/local.properties
# Read a local.properties value as a POSIX path (handles "E:\dir" escapes).
prop_path() {
  local v
  v=$(sed -n "s/^$1=//p" "$PROP_FILE" 2>/dev/null | tr -d '')
  [ -n "$v" ] || return 0
  v=${v//\\\\/\\}
  cygpath -u "$v" 2>/dev/null || echo "$v"
}
find_flutter() {
  if [ -n "${FLUTTER:-}" ]; then echo "$FLUTTER"; return; fi
  if command -v flutter >/dev/null 2>&1; then command -v flutter; return; fi
  local sdk; sdk=$(prop_path flutter.sdk)
  for c in "$sdk/bin/flutter" "$sdk/bin/flutter.bat"; do
    [ -n "$sdk" ] && [ -f "$c" ] && { echo "$c"; return; }
  done
  die "flutter not found (set FLUTTER=/path/to/flutter)"
}
FLUTTER_BIN=$(find_flutter)

find_aapt() {
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  [ -n "$sdk" ] || sdk=$(prop_path sdk.dir)
  ls "$sdk"/build-tools/*/aapt "$sdk"/build-tools/*/aapt.exe 2>/dev/null | sort -V | tail -1
}
AAPT=$(find_aapt)
[ -n "$AAPT" ] || die "aapt not found in Android SDK build-tools"

# --- version management ---------------------------------------------------
PUBSPEC=pubspec.yaml
line=$(grep -E '^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+[[:space:]]*$' "$PUBSPEC" | tr -d '\r') \
  || die "pubspec.yaml version must look like 1.2.3+4"
cur=${line#version:}; cur=${cur// /}
name=${cur%+*}; build=${cur#*+}
IFS=. read -r MAJ MIN PAT <<<"$name"

case "$BUMP" in
  major) MAJ=$((MAJ+1)); MIN=0; PAT=0; build=$((build+1)) ;;
  minor) MIN=$((MIN+1)); PAT=0; build=$((build+1)) ;;
  patch) PAT=$((PAT+1)); build=$((build+1)) ;;
  build) build=$((build+1)) ;;
  none) ;;
esac
NAME="$MAJ.$MIN.$PAT"; NEW="$NAME+$build"

cp "$PUBSPEC" "$PUBSPEC.release-bak"
ok=0
restore() {
  if [ "$ok" != 1 ]; then mv -f "$PUBSPEC.release-bak" "$PUBSPEC"; echo "Build failed - pubspec.yaml restored to $cur" >&2
  else rm -f "$PUBSPEC.release-bak"; fi
}
trap restore EXIT

sed -i "s/^version:.*/version: $NEW/" "$PUBSPEC"
[ "$(grep -c '^version:' "$PUBSPEC")" = 1 ] && grep -q "^version: $NEW\r\?$" "$PUBSPEC" || die "failed to write version to pubspec.yaml"
echo "Version: $cur -> $NEW"

# --- build ----------------------------------------------------------------
OUT="dist/$NAME+$build"
APK_DIR=build/app/outputs/flutter-apk
rm -rf "$OUT" "$APK_DIR"; mkdir -p "$OUT"

[ "$PUB_GET" = 1 ] && "$FLUTTER_BIN" pub get
echo "== universal APK =="
"$FLUTTER_BIN" build apk --release --build-name "$NAME" --build-number "$build"
cp "$APK_DIR/app-release.apk" "$OUT/musir-$NAME+$build-universal.apk"
echo "== split-per-abi APKs =="
"$FLUTTER_BIN" build apk --release --split-per-abi --build-name "$NAME" --build-number "$build"
ABIS="armeabi-v7a arm64-v8a x86_64"
for abi in $ABIS; do
  [ -f "$APK_DIR/app-$abi-release.apk" ] || die "missing split APK for $abi"
  cp "$APK_DIR/app-$abi-release.apk" "$OUT/musir-$NAME+$build-$abi.apk"
done

# --- validate -------------------------------------------------------------
echo "== validating =="
fail=0
check() { # label expected actual
  if [ "$2" = "$3" ]; then printf '  ok   %-34s %s\n' "$1" "$3"
  else printf '  FAIL %-34s expected %s, got %s\n' "$1" "$2" "$3"; fail=1; fi
}
check "pubspec.yaml version" "$NEW" "$(sed -n 's/^version:[[:space:]]*//p' "$PUBSPEC" | tr -d '\r')"
lp_name=$(sed -n 's/^flutter\.versionName=//p' android/local.properties 2>/dev/null | tr -d '\r')
lp_code=$(sed -n 's/^flutter\.versionCode=//p' android/local.properties 2>/dev/null | tr -d '\r')
[ -z "$lp_name$lp_code" ] || check "local.properties version" "$NEW" "$lp_name+$lp_code"

for f in universal $ABIS; do
  apk="$OUT/musir-$NAME+$build-$f.apk"
  [ -s "$apk" ] || { echo "  FAIL missing/empty $apk"; fail=1; continue; }
  badge=$("$AAPT" dump badging "$apk" | tr -d '\r' | head -1)
  vname=$(sed -n "s/.*versionName='\([^']*\)'.*/\1/p" <<<"$badge")
  vcode=$(sed -n "s/.*versionCode='\([^']*\)'.*/\1/p" <<<"$badge")
  check "$f versionName" "$NAME" "$vname"
  # Flutter's split-per-abi offsets versionCode by abi*1000: v7a=1, arm64=2, x86_64=4.
  case "$f" in universal) off=0 ;; armeabi-v7a) off=1000 ;; arm64-v8a) off=2000 ;; x86_64) off=4000 ;; esac
  check "$f versionCode" "$((build+off))" "$vcode"
  if [ "$f" != universal ]; then
    libs=$(unzip -l "$apk" | grep -o 'lib/[^/]*/' | sort -u | tr '\n' ' ')
    check "$f native libs" "lib/$f/ " "$libs"
  fi
done
[ "$fail" = 0 ] || die "validation failed"

ok=1
echo; echo "Release $NEW OK -> $OUT"; ls -l "$OUT" | tail -n +2
