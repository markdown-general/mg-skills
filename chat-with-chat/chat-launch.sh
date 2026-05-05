#!/bin/bash
# browser-launch.sh — Launch shared Chrome debug instance on macOS

set -euo pipefail

PROFILE_DIR="$HOME/.local/share/chrome-debug-profile"
PORT=9222

# Check if already running
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null; then
  echo "✅ Chrome already running on :$PORT"
  ./browser-list-tabs.js | head -n 20
  exit 0
fi

echo "🚀 Launching Chrome with debug profile..."

"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=$PORT \
  --user-data-dir="$PROFILE_DIR" \
  --no-first-run \
  --no-default-browser-check \
  --disable-background-networking \
  --disable-default-apps \
  &

sleep 3
echo "✅ Chrome launched. Waiting for tabs..."

./browser-list-tabs.js | head -n 15
