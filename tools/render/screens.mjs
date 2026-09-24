// Renders exported ScreenGui trees (tests/specs/05_client) to PNGs.
//   node tools/render/screens.mjs <screens.json> <outDir>
// screens.json: [{ name, w, h, background?, tree }] where background is a
// repo-relative image drawn behind the UI (approximate scene context).
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
let playwright;
try {
  playwright = require("playwright");
} catch {
  playwright = require("/opt/node22/lib/node_modules/playwright");
}

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");
const [screensArg, outArg] = process.argv.slice(2);
if (!screensArg || !outArg) {
  console.error("usage: screens.mjs <screens.json> <outDir>");
  process.exit(1);
}
const MIME = { ".html": "text/html", ".js": "text/javascript", ".json": "application/json", ".png": "image/png", ".woff2": "font/woff2" };
const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split("?")[0]);
  const file = path.join(repoRoot, url);
  if (!file.startsWith(repoRoot) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404);
    res.end("not found");
    return;
  }
  res.writeHead(200, { "Content-Type": MIME[path.extname(file)] || "application/octet-stream" });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const port = server.address().port;
const screens = JSON.parse(fs.readFileSync(screensArg, "utf8"));
const browser = await playwright.chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on("pageerror", (err) => console.log("[pageerror]", err.message));
await page.goto(`http://127.0.0.1:${port}/tools/render/guipage.html`);
await page.waitForFunction(() => window.__ready === true, null, { timeout: 60000 });
fs.mkdirSync(outArg, { recursive: true });
for (const screen of screens) {
  await page.setViewportSize({ width: screen.w, height: screen.h });
  const background = screen.background ? `#111 url(/${screen.background}) center / cover no-repeat` : "#1b1f1c";
  await page.evaluate(([tree, w, h, bg]) => window.renderInto(tree, w, h, { background: bg }), [screen.tree, screen.w, screen.h, background]);
  const file = path.join(outArg, `${screen.name}.png`);
  await page.locator("#stage").screenshot({ path: file });
  console.log("  " + file);
}
await browser.close();
server.close();
