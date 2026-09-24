// Renders preview images of an exported lobby scene.
//   node tools/render/render.mjs build/render/blockout.json docs/previews/blockout [viewSet]
// Uses the globally installed Playwright + the system Chromium.
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { VIEW_SETS } from "./views.mjs";

const require = createRequire(import.meta.url);
let playwright;
try {
  playwright = require("playwright");
} catch {
  playwright = require("/opt/node22/lib/node_modules/playwright");
}

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");
const [sceneArg, outArg, setArg] = process.argv.slice(2);
if (!sceneArg || !outArg) {
  console.error("usage: render.mjs <scene.json> <outPrefix> [viewSet]");
  process.exit(1);
}
const viewSet = VIEW_SETS[setArg || "overview"];
if (!viewSet) {
  console.error("unknown view set " + setArg + "; have " + Object.keys(VIEW_SETS).join(", "));
  process.exit(1);
}

const MIME = { ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json", ".png": "image/png" };
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

const width = 1600, height = 900;
const browser = await playwright.chromium.launch({
  args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
const page = await browser.newPage({ viewport: { width, height } });
page.on("console", (msg) => { if (msg.type() === "error") console.log("[page]", msg.text()); });
page.on("pageerror", (err) => console.log("[pageerror]", err.message));
await page.goto(`http://127.0.0.1:${port}/tools/render/viewer.html?w=${width}&h=${height}`);
await page.waitForFunction(() => window.__ready === true, null, { timeout: 60000 });
const sceneUrl = "/" + path.relative(repoRoot, path.resolve(sceneArg));
const t0 = Date.now();
const count = await page.evaluate(async (u) => await window.loadScene(u), sceneUrl);
console.log(`loaded ${count} parts in ${Date.now() - t0} ms`);

fs.mkdirSync(path.dirname(path.resolve(outArg)), { recursive: true });
for (const view of viewSet) {
  const t1 = Date.now();
  await page.evaluate((v) => window.setView(v), view);
  const file = `${outArg}-${view.name}.png`;
  await page.screenshot({ path: file });
  console.log(`  ${file} (${Date.now() - t1} ms)`);
}
await browser.close();
server.close();
