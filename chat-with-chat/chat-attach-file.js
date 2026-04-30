import puppeteer from "puppeteer-core";

const b = await puppeteer.connect({
  browserURL: "http://localhost:9222",
  defaultViewport: null,
});

const p = (await b.pages()).at(-1);
const filePath = process.argv[2];

if (!filePath) {
  console.error("Usage: node chat-attach-file.js <file-path>");
  process.exit(1);
}

const fileInput = await p.$('input[type="file"]');

if (fileInput) {
  await fileInput.uploadFile(filePath);
  console.log(`✓ File attached: ${filePath}`);
} else {
  console.error("✗ File input not found");
  process.exit(1);
}

await b.disconnect();
