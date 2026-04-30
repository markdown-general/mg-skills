#!/bin/bash
# chat-with-grok.sh — One-command robust chat with Grok
# Usage: ./chat-with-grok.sh "your message"          or
#        ./chat-with-grok.sh prompt-file.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

AUDIT_LOG="$HOME/mg/logs/browser-chat-audit.log"
TIMESTAMP=$(date +%s)

# --- Input handling ---
if [ $# -eq 0 ]; then
  echo "Usage: $0 <message or prompt-file>"
  exit 1
fi

if [ -f "$1" ]; then
  PROMPT_FILE="$1"
else
  PROMPT_FILE="/tmp/grok-prompt-$TIMESTAMP.txt"
  echo "$1" > "$PROMPT_FILE"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] CHAT START → Grok" | tee -a "$AUDIT_LOG"

# 1. Launch Chrome if needed
./browser-launch.sh

# 2. Send message
echo "Sending to Grok..."
./robust-send-to-grok.sh "$PROMPT_FILE"

# 3. Wait for response
RESPONSE_FILE="$HOME/mg/logs/grok-response-$TIMESTAMP.txt"
./robust-wait-for-grok.sh "$RESPONSE_FILE"

# 4. Output clean response
echo "────────────────────────────────────────"
cat "$RESPONSE_FILE"
echo "────────────────────────────────────────"
echo "✅ Response saved to: $RESPONSE_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] CHAT COMPLETE" | tee -a "$AUDIT_LOG"
