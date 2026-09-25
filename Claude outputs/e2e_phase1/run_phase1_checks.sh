#!/usr/bin/env bash
# Phase 1 E2E verification. Runs ONLY in a throwaway clone:
#   fresh clone of HEAD (fd244d4) + exactly the files in MANIFEST.txt.
# Your working tree, pubspec.lock, analysis_options.yaml and the deleted
# ios/.../Package.resolved are never touched. Nothing is committed/pushed.
set -u
REPO="$HOME/BookMyspace_Andriod"
OUT="$(cd "$(dirname "$0")" && pwd)/results"
WORK="/tmp/bms-e2e-phase1"
F="$HOME/.codex/toolchains/flutter-3.44.0/bin/flutter"
export PATH="$(dirname "$F"):$PATH"
mkdir -p "$OUT"; : > "$OUT/summary.txt"
say() { echo "$*" | tee -a "$OUT/summary.txt"; }

# run <label> <timeout_s> <cmd...> : logs to $OUT/<label>.log, records exit/duration
run() {
  local label=$1 cap=$2; shift 2
  local start=$(date +%s); "$@" > "$OUT/$label.log" 2>&1 &
  local pid=$! waited=0
  while kill -0 $pid 2>/dev/null; do sleep 5; waited=$((waited+5));
    if [ $waited -ge $cap ]; then
      ps -o pid,etime,command -p $pid > "$OUT/$label.TIMEOUT_ps.txt" 2>/dev/null
      pkill -P $pid 2>/dev/null; kill $pid 2>/dev/null; sleep 3; kill -9 $pid 2>/dev/null
      say "$label: TIMEOUT after ${cap}s"; wait $pid 2>/dev/null; return 124; fi
  done
  wait $pid; local rc=$?
  say "$label: exit=$rc duration=$(( $(date +%s)-start ))s | $(grep -aE '^[0-9]+:[0-9]+ \+[0-9]+|[0-9]+ (passed|failed)|PASSED|FAILED' "$OUT/$label.log" | tail -1)"
  return $rc
}

say "== Phase 1 checks $(date -u +%FT%TZ)"
[ -x "$F" ] || { say "ABORT: Flutter 3.44.0 not found at $F"; exit 2; }
"$F" --version 2>&1 | head -1 | tee -a "$OUT/summary.txt"

# 1. Throwaway clone = HEAD + manifest files only
rm -rf "$WORK"; git clone --quiet --no-hardlinks "$REPO" "$WORK" || { say "ABORT: clone failed"; exit 2; }
git -C "$WORK" checkout --quiet --detach "$(git -C "$REPO" rev-parse HEAD)"
while IFS= read -r f; do mkdir -p "$WORK/$(dirname "$f")"; cp -p "$REPO/$f" "$WORK/$f"; done < "$(dirname "$0")/MANIFEST.txt"
git -C "$WORK" status --porcelain > "$OUT/clone_status.txt"
say "clone HEAD=$(git -C "$WORK" rev-parse --short HEAD); changed paths: $(wc -l < "$OUT/clone_status.txt")"
cd "$WORK"
run pub_get 600 "$F" pub get

# 2. Existing + new Flutter unit/widget tests, 3. analyzer baseline
run flutter_unit_widget 1800 "$F" test --no-pub --coverage
run analyzer_baseline 900 env FLUTTER_BIN="$F" python3 scripts/validate_analyzer_baseline.py
git diff --check > "$OUT/diff_check.txt" 2>&1; say "git_diff_check: exit=$?"

# 4. Integration smoke on iOS simulator (if Xcode present)
if command -v xcrun >/dev/null && xcrun simctl list >/dev/null 2>&1; then
  SIM=$(xcrun simctl list devices booted -j | python3 -c "import json,sys;d=json.load(sys.stdin)['devices'];print(next((x['udid'] for v in d.values() for x in v if x['state']=='Booted'),''))")
  BOOTED_BY_US=""
  if [ -z "$SIM" ]; then
    SIM=$(xcrun simctl list devices available -j | python3 -c "import json,sys;d=json.load(sys.stdin)['devices'];print(next((x['udid'] for k,v in d.items() if 'iOS' in k for x in v if x['name'].startswith('iPhone')),''))")
    [ -n "$SIM" ] && xcrun simctl boot "$SIM" && BOOTED_BY_US=1 && sleep 20
  fi
  if [ -n "$SIM" ]; then
    run ios_smoke 2700 "$F" test integration_test/e2e_test.dart -d "$SIM" --no-pub --dart-define=E2E_TAGS=smoke
    [ -n "$BOOTED_BY_US" ] && xcrun simctl shutdown "$SIM"
  else say "ios_smoke: BLOCKED - no iPhone simulator available (xcrun simctl list devices available)"; fi
else say "ios_smoke: BLOCKED - Xcode command line tools / simctl not available"; fi

# 5. Integration smoke on Android emulator (if SDK present)
ADB=$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")
EMU=$(command -v emulator || echo "$HOME/Library/Android/sdk/emulator/emulator")
if [ -x "$ADB" ]; then
  DEV=$("$ADB" devices | awk 'NR>1 && $2=="device"{print $1; exit}'); EMU_PID=""
  if [ -z "$DEV" ] && [ -x "$EMU" ]; then
    AVD=$("$EMU" -list-avds | head -1)
    if [ -n "$AVD" ]; then "$EMU" -avd "$AVD" -no-window -no-audio -no-snapshot-save > "$OUT/emulator.log" 2>&1 & EMU_PID=$!
      "$ADB" wait-for-device; for i in $(seq 1 60); do [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break; sleep 5; done
      DEV=$("$ADB" devices | awk 'NR>1 && $2=="device"{print $1; exit}'); fi
  fi
  if [ -n "$DEV" ]; then run android_smoke 2700 "$F" test integration_test/e2e_test.dart -d "$DEV" --no-pub --dart-define=E2E_TAGS=smoke
  else say "android_smoke: BLOCKED - no running device and no AVD (emulator -list-avds is empty)"; fi
  [ -n "$EMU_PID" ] && { "$ADB" -s "$DEV" emu kill >/dev/null 2>&1; kill $EMU_PID 2>/dev/null; }
else say "android_smoke: BLOCKED - adb not found (Android SDK platform-tools missing)"; fi

# 6. Web: mock build + Playwright smoke
if command -v node >/dev/null && command -v npm >/dev/null; then
  run web_build_mock 1200 "$F" build web --release --no-pub -t integration_test/web_mock_main.dart --output build/e2e_web_mock
  cd e2e-playwright
  run npm_ci 600 npm ci --no-audit --no-fund
  run playwright_install 900 npx playwright install chromium
  run web_smoke 1800 env CI=1 npx playwright test --grep @smoke
  rm -rf "$OUT/playwright-reports" "$OUT/playwright-test-results"   # never mix runs
  cp -R reports "$OUT/playwright-reports" 2>/dev/null; cp -R test-results "$OUT/playwright-test-results" 2>/dev/null
  cd "$WORK"
else say "web_smoke: BLOCKED - node/npm not on PATH"; fi

# 7. Proof the real repo was untouched
say "real repo status unchanged: $(cd "$REPO" && git status --porcelain=v1 | diff -q - "$(dirname "$0")/../e2e_phase1/status_after_phase1.txt" >/dev/null 2>&1 && echo yes || echo 'see status_real.txt')"
(cd "$REPO" && git status --porcelain=v1 > "$OUT/status_real.txt"; shasum -a 256 pubspec.lock pubspec.yaml analysis_options.yaml > "$OUT/sha_real.txt")
say "DONE $(date -u +%FT%TZ)"; echo DONE > "$OUT/DONE"
