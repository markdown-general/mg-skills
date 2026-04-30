#!/bin/bash
# chrome-open-macos.sh — Launch Chrome on macOS with CDP enabled
# Usage: chrome-open-macos.sh
#
# Checks if Chrome is already running. If not, launches it with debug profile.
# Waits for CDP port 9222 to be ready before returning.

# Check if Chrome is already running on 9222
if curl -s http://localhost:9222/json/list > /dev/null 2>&1; then
  echo "✓ Chrome already running on :9222"
  exit 0
fi

# Launch Chrome with remote debugging
echo "Launching Chrome with remote debugging..."
CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DEBUG_PROFILE="$HOME/chrome-debug-profile"
mkdir -p "$DEBUG_PROFILE"
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
