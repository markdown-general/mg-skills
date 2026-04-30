import puppeteer from "puppeteer-core";

const b = await puppeteer.connect({
  browserURL: "http://localhost:9222",
  defaultViewport: null,
});

const p = (await b.pages()).at(-1);
const fileInput = await p.$('input[type="file"]');

if (fileInput) {
  await fileInput.uploadFile('/Users/tonyday567/mg/logs/materials-for-critique.txt');
  console.log('✓ File uploaded');
  await new Promise(r => setTimeout(r, 1500));
  
  // Click send
  await p.evaluate(() => {
    const sendBtn = document.querySelector('button svg[viewBox="0 0 256 256"]')?.closest('button');
    if (sendBtn) sendBtn.click();
  });
  console.log('✓ Message sent');
  
  // Wait for response
  await new Promise(r => setTimeout(r, 15000));
  
  // Capture response
  const text = await p.evaluate(() => document.body.innerText);
  console.log(text.slice(-2000));
} else {
  console.log('✗ File input not found');
}

await b.disconnect();
