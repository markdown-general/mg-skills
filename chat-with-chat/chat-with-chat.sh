#!/bin/bash
# chat-with-chat.sh — One command for any AI system
# Usage: ./chat-with-chat.sh <system> <prompt>
#        ./chat-with-chat.sh grok "What is X?"
#        ./chat-with-chat.sh claude "Explain Y"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

AUDIT_LOG="$HOME/mg/logs/browser-chat-audit.log"
TIMESTAMP=$(date +%s)

if [ $# -lt 2 ]; then
  echo "Usage: $0 <system> <prompt>"
  echo "Systems: grok, claude"
  exit 1
fi

SYSTEM=$(echo "$1" | tr '[:upper:]' '[:lower:]')
shift
PROMPT="$*"

# Build temp prompt file
PROMPT_FILE="/tmp/ai-prompt-$TIMESTAMP.txt"
echo "$PROMPT" > "$PROMPT_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] CHAT START → $SYSTEM" | tee -a "$AUDIT_LOG"

# 1. Health check (optional but recommended)
if ! ./chat-health-check.sh "$SYSTEM" 2>&1 | tail -3; then
  echo ""
  echo "⚠️  Health check found issues. Continuing anyway..."
  echo "    (Run ./chat-health-check.sh $SYSTEM for details)"
fi

# 2. Send message
echo "Sending to $SYSTEM..."
./chat-send.sh "$SYSTEM" "$PROMPT_FILE"

# 3. Wait for response
RESPONSE_FILE="$HOME/mg/logs/${SYSTEM}-response-$TIMESTAMP.txt"
./chat-wait.sh "$SYSTEM" "$RESPONSE_FILE"

# 4. Output clean response
echo "────────────────────────────────────────"
cat "$RESPONSE_FILE"
echo "────────────────────────────────────────"
echo "✅ Response saved to: $RESPONSE_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] CHAT COMPLETE" | tee -a "$AUDIT_LOG"

# Cleanup
rm -f "$PROMPT_FILE"
