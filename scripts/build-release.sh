#!/bin/bash
# build-release.sh — TapeScan pre-release verification (M9).
#
# Runs the full local gate: regenerate project, unit + UI tests, Debug and
# Release simulator builds, device-SDK compile, and a placeholder audit.
# Archive/upload requires the owner's DEVELOPMENT_TEAM (see the end).

set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="TapeMeasureARPro.xcodeproj"
SCHEME="TapeScan"
SIM_DEST='platform=iOS Simulator,name=iPhone 17 Pro'

echo "▸ xcodegen"
xcodegen generate

echo "▸ unit + UI tests (Debug, simulator)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$SIM_DEST" \
  CODE_SIGNING_ALLOWED=NO test | tail -3

echo "▸ Release build (simulator)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build | tail -1

echo "▸ Device-SDK compile (unsigned)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build | tail -1

echo "▸ warning audit (app sources)"
WARNINGS=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO \
  clean build 2>&1 | grep -E '\bwarning:' \
  | grep -vE 'appintentsmetadataprocessor|SourcePackages|checkouts' || true)
if [[ -n "$WARNINGS" ]]; then
  echo "$WARNINGS"
  echo "✗ compiler warnings present"; exit 1
fi

echo "▸ placeholder audit"
if grep -rn 'REPLACE-WITH-PROJECT\|REPLACE_WITH_ANON_KEY' Sources --include='*.swift' >/dev/null; then
  if [[ "${RELEASE_ARCHIVE:-0}" == "1" ]]; then
    echo "✗ SupabaseConfig still has placeholder credentials — refusing to archive (auth, sync, and account deletion would fail at runtime)"; exit 1
  fi
  echo "⚠ SupabaseConfig still has placeholder credentials (sync reports 'not configured'). Set RELEASE_ARCHIVE=1 to make this a hard failure for archive builds."
fi
if grep -rn '"TapeMeasure\|OWNER-INPUT\|OWNER-GITHUB' Sources --include='*.swift'; then
  echo "✗ unresolved placeholders"; exit 1
fi

echo "✓ all local gates passed"
echo
echo "To archive for App Store Connect (owner steps):"
echo "  1. project.yml → uncomment DEVELOPMENT_TEAM, set CODE_SIGNING_ALLOWED/REQUIRED: YES"
echo "  2. xcodegen generate"
echo "  3. xcodebuild -project $PROJECT -scheme $SCHEME -configuration Release \\"
echo "       -destination 'generic/platform=iOS' archive -archivePath build/TapeScan.xcarchive"
echo "  4. Xcode → Organizer → Distribute (or xcodebuild -exportArchive)"
