import puppeteer from "puppeteer-core";

const b = await puppeteer.connect({
  browserURL: "http://localhost:9222",
  defaultViewport: null,
});

const p = (await b.pages()).at(-1);

// Read materials
const fs = await import("fs");
const materials = fs.readFileSync('/Users/tonyday567/mg/logs/materials-for-critique.txt', 'utf8');

// Paste into chat
await p.evaluate((text) => {
  const input = document.querySelector('[data-testid="chat-input"]');
  if (input) {
    input.focus();
    input.innerText = text;
  }
}, materials);

console.log('✓ Materials pasted');
await new Promise(r => setTimeout(r, 1000));

// Send
await p.evaluate(() => {
  document.querySelector('button svg[viewBox="0 0 256 256"]')?.closest('button')?.click();
});

console.log('✓ Sent');

// Wait for Claude to analyze
await new Promise(r => setTimeout(r, 45000));

// Capture
const response = await p.evaluate(() => document.body.innerText);
fs.writeFileSync('/Users/tonyday567/mg/logs/critique-response.txt', response);
console.log('✓ Response saved to critique-response.txt');

await b.disconnect();
