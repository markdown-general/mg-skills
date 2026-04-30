#!/bin/bash
# chrome-open-macos.sh — Launch Chrome on macOS with CDP enabled
# Usage: chrome-open-macos.sh [--profile]
#
# Chrome 136+ requires non-default data directory for remote debugging.
# --profile: Copy your actual Chrome profile (keeps logins/cookies)
# (default): Use isolated debug profile (fresh session)

CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DEBUG_PROFILE="$HOME/chrome-debug-profile"
REAL_PROFILE="$HOME/Library/Application Support/Google/Chrome"

# Check if Chrome already running on 9222
if curl -s http://localhost:9222/json/list > /dev/null 2>&1; then
  echo "✓ Chrome already running on :9222"
  exit 0
fi

# Setup debug profile
mkdir -p "$DEBUG_PROFILE"

if [[ "$1" == "--profile" ]]; then
  # Copy real profile to preserve logins/cookies
  if [[ -d "$REAL_PROFILE/Default" ]]; then
    echo "Copying your Chrome profile (keeping logins)..."
    cp -R "$REAL_PROFILE/Default" "$DEBUG_PROFILE/Default" 2>/dev/null || true
  fi
fi

# Launch Chrome with remote debugging
echo "Launching Chrome with remote debugging..."
"$CHROME_BIN" --remote-debugging-port=9222 --user-data-dir="$DEBUG_PROFILE" > /dev/null 2>&1 &

# Wait for CDP port to be ready (max 10 seconds)
for i in {1..20}; do
  if curl -s http://localhost:9222/json/list > /dev/null 2>&1; then
    echo "✓ Chrome CDP ready on :9222"
    exit 0
  fi
  sleep 0.5
done

echo "✗ Chrome failed to start or CDP not responding"
exit 1
