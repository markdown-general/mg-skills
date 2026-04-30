#!/bin/bash
# robust-send.sh — Generic send for any AI system via config
# Usage: ./robust-send.sh <system> <message-file>
# Systems: grok, claude

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/browser-tools.conf"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <system> <message-file>"
  echo "Systems: grok, claude"
  exit 1
fi

SYSTEM=$(echo "$1" | tr '[:upper:]' '[:lower:]')
MESSAGE_FILE="$2"
AUDIT_LOG="$HOME/mg/logs/browser-chat-audit.log"

# Load system-specific config
SYSTEM_UPPER=$(echo "$SYSTEM" | tr '[:lower:]' '[:upper:]')
INPUT_VAR="${SYSTEM_UPPER}_INPUT_SELECTOR"
SEND_VAR="${SYSTEM_UPPER}_SEND_SELECTOR"

INPUT_SELECTOR="${!INPUT_VAR}"
SEND_SELECTOR="${!SEND_VAR}"

if [ -z "$INPUT_SELECTOR" ] || [ -z "$SEND_SELECTOR" ]; then
  echo "❌ Unknown system: $SYSTEM"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] SEND START → $SYSTEM" | tee -a "$AUDIT_LOG"

# 1. Ensure correct tab
echo "Ensuring $SYSTEM tab..."
DOMAIN=$([ "$SYSTEM" = "grok" ] && echo "grok.com" || echo "claude.ai")
TAB_INFO=$("$SCRIPT_DIR/browser-ensure-tab.js" "$DOMAIN")
TAB_INDEX=$(echo "$TAB_INFO" | jq -r '.tabIndex // .index // -1')

if [ "$TAB_INDEX" = "-1" ]; then
  echo "❌ Could not find $SYSTEM tab"
  exit 1
fi

echo "✅ $SYSTEM tab ready (index $TAB_INDEX)"

# 2. Read and escape message
INPUT=$(cat "$MESSAGE_FILE")
ESCAPED=$(python3 -c "
import json, sys
print(json.dumps(sys.stdin.read().strip()))
" <<< "$INPUT")

# 3. Paste into input (system-specific)
"$SCRIPT_DIR/browser-eval.js" "(function() {
  var editor = document.querySelector('$INPUT_SELECTOR');
  if (editor) {
    editor.innerText = $ESCAPED;
    editor.dispatchEvent(new Event('input', { bubbles: true }));
    return '✅ Text pasted';
  } else {
    return 'Input editor not found';
  }
})()"

sleep 1.5

# 4. Click send
"$SCRIPT_DIR/browser-eval.js" "(function() {
  var sendBtn = document.querySelector('$SEND_SELECTOR');
  if (sendBtn) {
    sendBtn.click();
    return '✅ Send clicked';
  } else {
    return 'Send button not found';
  }
})()"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] SEND COMPLETE" | tee -a "$AUDIT_LOG"
