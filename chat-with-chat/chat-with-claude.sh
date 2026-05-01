#!/bin/bash
# chat-with-claude.sh — Directed session harness for Claude via chat-with-chat
# Usage: ./chat-with-claude.sh <prompt-file-or-string>
#        ./chat-with-claude.sh loom/agent-f.md       # feed a card as prompt
#        ./chat-with-claude.sh "What is a functor?"  # inline prompt
#
# Multi-turn: run repeatedly in same Claude tab; context accumulates.
# Output: appended to loom/claude-session-<date>.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_LOG="$HOME/mg/loom/claude-session-$(date +%Y-%m-%d).md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ $# -lt 1 ]; then
  echo "Usage: $0 <prompt-file-or-string>"
  exit 1
fi

INPUT="$*"

# Resolve: file or inline string?
if [ -f "$INPUT" ]; then
  PROMPT=$(cat "$INPUT")
  SOURCE="$INPUT"
else
  PROMPT="$INPUT"
  SOURCE="inline"
fi

# Ensure session log directory exists
mkdir -p "$(dirname "$SESSION_LOG")"

# Append prompt to session log
cat >> "$SESSION_LOG" <<EOF

---

## ⟝ $TIMESTAMP · $SOURCE

**prompt:**

$PROMPT

**response:**

EOF

# Send via chat-with-chat and capture the response
RESPONSE=$("$SCRIPT_DIR/chat-with-chat.sh" claude "$PROMPT" 2>&1 | tail -1)

# Append response to session log
echo "$RESPONSE" >> "$SESSION_LOG"

# Echo to stdout
echo "$RESPONSE"

echo ""
echo "⟜ session log: $SESSION_LOG"
