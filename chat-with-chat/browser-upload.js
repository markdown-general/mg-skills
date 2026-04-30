#!/usr/bin/env node
// Upload files to the current page's file input.
// Usage: browser-upload.js <file1> [file2 ...]

import puppeteer from "puppeteer-core";

const files = process.argv.slice(2);

if (files.length === 0) {
	console.log("Usage: browser-upload.js <file1> [file2 ...]");
	process.exit(1);
}

const browser = await puppeteer.connect({
	browserURL: "http://localhost:9222",
	defaultViewport: null,
});

const pages = await browser.pages();
const page = pages[pages.length - 1];

const fileInput = await page.$('input[type="file"]');
if (!fileInput) {
	console.error("✗ No file input found on current page");
	await browser.disconnect();
	process.exit(1);
}

await fileInput.uploadFile(...files);
console.log(`✓ Uploaded ${files.length} file(s):`, files.join(", "));

await browser.disconnect();
