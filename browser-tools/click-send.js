import puppeteer from "puppeteer-core";

const b = await puppeteer.connect({
  browserURL: "http://localhost:9222",
  defaultViewport: null,
});

const p = (await b.pages()).at(-1);

// Click send button (last one)
await p.evaluate(() => {
  const buttons = Array.from(document.querySelectorAll('button svg[viewBox="0 0 256 256"]'));
  if (buttons.length > 0) {
    buttons[buttons.length - 1].closest('button').click();
  }
});

console.log('✓ Clicked send');

// Wait for response
await new Promise(r => setTimeout(r, 15000));

// Check input is empty (message was sent)
const inputText = await p.evaluate(() => {
  return document.querySelector('[data-testid="chat-input"]')?.innerText || "";
});

if (inputText.length === 0) {
  console.log('✓ Message sent (input cleared)');
} else {
  console.log('✗ Message not sent (input still has text)');
}

await b.disconnect();
