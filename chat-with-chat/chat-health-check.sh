#!/bin/bash
# chat-health-check.sh — Verify preconditions for chat-with-chat operations
# Usage: ./chat-health-check.sh [system]
#        ./chat-health-check.sh grok
#        ./chat-health-check.sh claude
#        ./chat-health-check.sh           # Check all systems

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/browser-tools.conf"

SYSTEM="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Chat Health Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

FAILED=0

# 1. Check CDP connectivity
echo ""
echo "1. Chrome DevTools Protocol (CDP) on :9222..."
if curl -s http://localhost:9222/json/list > /dev/null 2>&1; then
  echo -e "${GREEN}✅ CDP port :9222 responding${NC}"
else
  echo -e "${RED}❌ CDP port :9222 not responding${NC}"
  echo "   Fix: Run ./browser-launch.sh to start Chrome"
  FAILED=1
fi

# 2. List all open tabs
echo ""
echo "2. Open tabs:"
TABS=$(curl -s http://localhost:9222/json/list 2>/dev/null || echo "[]")
TAB_COUNT=$(echo "$TABS" | jq 'length')
echo "   Found $TAB_COUNT tab(s)"
echo "$TABS" | jq -r '.[] | "   \(.id | .[0:8]): \(.url) — \(.title)"' 2>/dev/null || echo "   (could not parse tabs)"

# 3. Check specific system(s)
if [ -z "$SYSTEM" ]; then
  # Check all configured systems
  SYSTEMS=(grok claude)
else
  SYSTEMS=("$SYSTEM")
fi

for SYS in "${SYSTEMS[@]}"; do
  SYS_LOWER=$(echo "$SYS" | tr '[:upper:]' '[:lower:]')
  SYS_UPPER=$(echo "$SYS_LOWER" | tr '[:lower:]' '[:upper:]')
  
  URL_VAR="${SYS_UPPER}_URL_PATTERN"
  INPUT_VAR="${SYS_UPPER}_INPUT_SELECTOR"
  
  URL_PATTERN="${!URL_VAR:-}"
  INPUT_SELECTOR="${!INPUT_VAR:-}"
  
  if [ -z "$URL_PATTERN" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  System '$SYS_LOWER' not configured${NC}"
    echo "   Add to browser-tools.conf: [$SYS_UPPER] section"
    FAILED=1
    continue
  fi
  
  echo ""
  echo "3. System: $SYS_LOWER"
  
  # Find tab matching URL pattern
  TAB_FOUND=$(echo "$TABS" | jq -r ".[] | select(.url | contains(\"$URL_PATTERN\")) | .id" 2>/dev/null | head -1)
  
  if [ -z "$TAB_FOUND" ]; then
    echo -e "   ${RED}❌ No tab found matching '$URL_PATTERN'${NC}"
    echo "   Fix: Open https://$URL_PATTERN in Chrome and stay on that tab"
    FAILED=1
  else
    echo -e "   ${GREEN}✅ Tab found${NC}"
    TAB_URL=$(echo "$TABS" | jq -r ".[] | select(.id == \"$TAB_FOUND\") | .url")
    echo "      URL: $TAB_URL"
    
    # Check for login indicators (heuristic)
    PAGE_TEXT=$(curl -s "http://localhost:9222/devtools/page/$TAB_FOUND" 2>/dev/null | head -c 500)
    if echo "$PAGE_TEXT" | grep -qi "sign in\|login\|password"; then
      echo -e "   ${YELLOW}⚠️  Possible login screen detected${NC}"
      echo "   Fix: Log in to $SYS_LOWER in the Chrome tab and try again"
    else
      echo -e "   ${GREEN}✅ Login screen not detected${NC}"
    fi
    
    # Check for input field (via selector)
    if [ -n "$INPUT_SELECTOR" ]; then
      INPUT_CHECK=$("$SCRIPT_DIR/browser-eval.js" "document.querySelector('$INPUT_SELECTOR') !== null" 2>/dev/null || echo "false")
      if [ "$INPUT_CHECK" = "true" ]; then
        echo -e "   ${GREEN}✅ Input field found${NC}"
      else
        echo -e "   ${YELLOW}⚠️  Input field not found (selector: $INPUT_SELECTOR)${NC}"
        echo "   Fix: Verify you're logged in and the page is fully loaded"
      fi
    fi
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✅ All checks passed — ready to chat${NC}"
  exit 0
else
  echo -e "${RED}❌ Some checks failed — see fixes above${NC}"
  exit 1
fi
