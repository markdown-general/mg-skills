import puppeteer from "puppeteer-core";
import fs from "fs";

const b = await puppeteer.connect({
  browserURL: "http://localhost:9222",
  defaultViewport: null,
});

const p = (await b.pages()).at(-1);

// Paste prompt into input
const prompt = `What is best-practice for a pipeline from pdf to markdown + images + latex recovery?

The pipeline is part of a knowledge discovery process and has a very light operational demand (2M of pdfs a day say) and a focus on fidelity. 

OCR should be fine, but doesn't need to be super fine.`;

await p.evaluate((text) => {
  const input = document.querySelector('[data-testid="chat-input"]');
  if (input) {
    input.focus();
    input.innerText = text;
  }
}, prompt);

console.log('✓ Prompt pasted');
await new Promise(r => setTimeout(r, 1000));

// Click attach button
await p.evaluate(() => {
  const attachBtn = document.querySelector('div[id*="_r_cr_"]');
  if (attachBtn) attachBtn.click();
});

console.log('✓ Attach button clicked');
await new Promise(r => setTimeout(r, 1500));

// Upload file
const fileInput = await p.$('input[type="file"]');
if (fileInput) {
  await fileInput.uploadFile('/Users/tonyday567/mg/word/poise.md');
  console.log('✓ File uploaded');
} else {
  console.log('✗ File input not found');
}

await new Promise(r => setTimeout(r, 2000));

// Click send
await p.evaluate(() => {
  const sendBtn = document.querySelector('button svg[viewBox="0 0 256 256"]')?.closest('button');
  if (sendBtn) sendBtn.click();
});

console.log('✓ Message sent');

// Wait for response
await new Promise(r => setTimeout(r, 25000));

// Capture response
const response = await p.evaluate(() => document.body.innerText);
fs.writeFileSync('/Users/tonyday567/mg/logs/pdf-pipeline-response.txt', response);
console.log('✓ Response saved');

await b.disconnect();
