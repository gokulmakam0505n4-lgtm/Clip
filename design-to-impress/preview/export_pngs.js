// Renders each screen of design-to-impress-preview.html to a PNG (844x390 at 2x = 1688x780).
// Usage: node export_pngs.js   (needs Playwright + Chromium)
const { chromium } = require("playwright");
const path = require("path");
const fs = require("fs");

const SHOTS = [
  ["01-lobby", "screen=lobby"],
  ["02-theme-reveal", "screen=theme-reveal"],
  ["03-design-catalogue", "screen=design&design=catalogue"],
  ["04-design-placing", "screen=design&design=placing"],
  ["05-voting", "screen=voting"],
  ["06-results", "screen=results"],
  ["07-shop", "screen=shop"],
];

(async () => {
  const out = path.join(__dirname, "screens");
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 844, height: 390 }, deviceScaleFactor: 2 });
  const file = "file://" + path.join(__dirname, "design-to-impress-preview.html");
  for (const [name, query] of SHOTS) {
    await page.goto(`${file}?png=1&${query}`);
    await page.waitForFunction(() => window.__ready === true, null, { timeout: 15000 });
    await page.waitForTimeout(300);
    await page.locator("#stage").screenshot({ path: path.join(out, name + ".png") });
    console.log("saved", name + ".png");
  }
  await browser.close();
})();
