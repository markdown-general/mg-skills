#!/usr/bin/env node

import puppeteer from 'puppeteer-core';

async function ensureTab(pattern) {
  if (!pattern) {
    console.error('Usage: browser-ensure-tab.js <url-pattern>');
    console.error('Example: browser-ensure-tab.js grok.com');
    process.exit(1);
  }

  try {
    const browser = await puppeteer.connect({
      browserURL: 'http://localhost:9222'
    });

    const pages = await browser.pages();
    if (pages.length === 0) {
      console.error('❌ No tabs open');
      console.error('\nTip: Start Chrome with remote debugging enabled:');
      console.error('  /Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome \\');
      console.error('    --remote-debugging-port=9222 \\');
      console.error('    --user-data-dir=$HOME/.local/share/chrome-debug-profile');
      process.exit(1);
    }

    // Find tab matching pattern (case-insensitive)
    const patternLower = pattern.toLowerCase();
    const targetPage = pages.find(p => p.url().toLowerCase().includes(patternLower));

    if (!targetPage) {
      // List all open tabs for user
      console.error(`❌ No tab found matching "${pattern}"\n`);
      console.error('Current open tabs:');
      pages.forEach((p, i) => {
        console.error(`  ${i}. ${p.url()}`);
      });
      console.error('\nTip: Open the page first with:');
      console.error(`  browser-nav.js https://${pattern}`);
      process.exit(1);
    }

    // Get tab info before bringing to front
    const url = targetPage.url();
    const title = await targetPage.title();
    const tabIndex = pages.indexOf(targetPage);

    // Try to bring tab to front (best effort)
    try {
      const targetId = targetPage._target._targetInfo.targetId;
      await targetPage._client.send('Target.activateTarget', { targetId });
    } catch (e) {
      // Silently fail; still return success if tab found
    }

    // Output clean JSON to stdout
    console.log(JSON.stringify({
      ok: true,
      tabIndex,
      url,
      title,
      pattern
    }, null, 2));

    // Friendly message to stderr
    console.error(`✅ Tab found: "${title}" (index ${tabIndex})`);

    await browser.disconnect();
    process.exit(0);
  } catch (error) {
    console.error(`❌ Error: ${error.message}`);
    console.error('\nTroubleshooting:');
    console.error('1. Is Chrome running with --remote-debugging-port=9222?');
    console.error('2. Try: curl -s http://localhost:9222/json/list | jq');
    console.error('3. Check Chrome process: ps aux | grep "remote-debugging"');
    process.exit(1);
  }
}

const pattern = process.argv[2];
ensureTab(pattern);
