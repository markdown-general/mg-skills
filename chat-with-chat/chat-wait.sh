#!/bin/bash
# chat-wait.sh — Generic wait + extract for any AI system via config
# Usage: ./chat-wait.sh <system> <output-file>
# Systems: grok, claude

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/chat-tools.conf"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <system> <output-file>"
  echo "Systems: grok, claude"
  exit 1
fi

SYSTEM=$(echo "$1" | tr '[:upper:]' '[:lower:]')
OUTPUT_FILE="$2"
AUDIT_LOG="$HOME/mg/logs/browser-chat-audit.log"

# Load system-specific config
SYSTEM_UPPER=$(echo "$SYSTEM" | tr '[:lower:]' '[:upper:]')
BUBBLE_VAR="${SYSTEM_UPPER}_BUBBLE_CLASS"
TIMEOUT_VAR="${SYSTEM_UPPER}_TIMEOUT"
INTERVAL_VAR="${SYSTEM_UPPER}_INTERVAL"

BUBBLE_CLASS="${!BUBBLE_VAR}"
TIMEOUT="${!TIMEOUT_VAR}"
INTERVAL="${!INTERVAL_VAR}"

if [ -z "$BUBBLE_CLASS" ]; then
  echo "❌ Unknown system: $SYSTEM"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WAIT START → $SYSTEM" | tee -a "$AUDIT_LOG"

for ((i=0; i<TIMEOUT/INTERVAL; i++)); do
  # Check streaming status
  STREAMING=$("$SCRIPT_DIR/browser-eval.js" "
    (function() {
      var bubbles = document.querySelectorAll('$BUBBLE_CLASS');
      var last = bubbles[bubbles.length - 1];
      return last ? (last.innerText.trim().endsWith('...') || last.querySelector('.animate-pulse, .streaming') !== null) : false;
    })()
  " 2>/dev/null || echo "false")

  if [ "$STREAMING" = "false" ]; then
    echo "✅ Response complete — extracting full rich response"

    # Extract full HTML from .standard-markdown div within the last response
    HTML_OUTPUT=$("$SCRIPT_DIR/browser-eval.js" "
      (function() {
        var bubbles = Array.from(document.querySelectorAll('$BUBBLE_CLASS'));
        var lastMsg = bubbles[bubbles.length - 1];
        
        // Skip very short messages (likely user echo)
        if (lastMsg && lastMsg.innerText.length < 50) {
          lastMsg = bubbles[bubbles.length - 2];
        }
        
        if (!lastMsg) return 'No message found';
        
        // Try to find .standard-markdown div for rich formatting
        var richContent = lastMsg.querySelector('.standard-markdown');
        if (richContent) {
          return richContent.innerHTML;
        }
        
        // Fallback: return plain text
        return lastMsg.innerText.trim();
      })()
    ")
    
    # Convert HTML to markdown if pandoc is available
    if command -v pandoc &> /dev/null && [ "$HTML_OUTPUT" != "No message found" ]; then
      echo "$HTML_OUTPUT" | pandoc -f html -t markdown > "$OUTPUT_FILE"
    else
      echo "$HTML_OUTPUT" > "$OUTPUT_FILE"
    fi

    cp "$OUTPUT_FILE" "$HOME/mg/logs/${SYSTEM}-response-$(date +%s).txt"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WAIT COMPLETE — full response saved" | tee -a "$AUDIT_LOG"
    exit 0
  fi

  sleep "$INTERVAL"
done

echo "⚠️ Timeout waiting for $SYSTEM response"
exit 1
