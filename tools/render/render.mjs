// Renders preview images of an exported lobby scene.
//   node tools/render/render.mjs <scene.json> <outPrefix> [viewSet]
// If <scene>-guis.json exists (SurfaceGui trees from tests/lib/GuiExport),
// every SurfaceGui is first rendered to a PNG with gui.js and mapped onto
// its part face, so signs, screens and flags show their real content.
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
// ---- SurfaceGui pass --------------------------------------------------
const guisFile = path.resolve(sceneArg).replace(/\.json$/, "-guis.json");
let sceneFile = path.resolve(sceneArg);
if (fs.existsSync(guisFile)) {
  const surfaces = JSON.parse(fs.readFileSync(guisFile, "utf8"));
  const outDir = path.resolve(sceneArg).replace(/\.json$/, "-surfaces");
  fs.mkdirSync(outDir, { recursive: true });
  const guiPage = await browser.newPage({ viewport: { width: 1800, height: 1400 } });
  guiPage.on("pageerror", (err) => console.log("[gui pageerror]", err.message));
  await guiPage.goto(`http://127.0.0.1:${port}/tools/render/guipage.html`);
  await guiPage.waitForFunction(() => window.__ready === true, null, { timeout: 60000 });
  const placed = [];
  const t2 = Date.now();
  for (const s of surfaces) {
    const [pw, ph] = s.px;
    if (pw < 2 || ph < 2 || pw > 4000 || ph > 4000) continue;
    await guiPage.setViewportSize({ width: Math.max(pw, 16), height: Math.max(ph, 16) });
    await guiPage.evaluate(([tree, w, h]) => window.renderInto(tree, w, h), [s.tree, pw, ph]);
    const file = path.join(outDir, `${s.id}.png`);
    await guiPage.locator("#stage").screenshot({ path: file, omitBackground: true });
    placed.push({ image: "/" + path.relative(repoRoot, file), w: s.w, h: s.h, c: s.c, glow: Math.max(0, 1 - s.light) * 0.55 });
  }
  await guiPage.close();
  const scene = JSON.parse(fs.readFileSync(sceneFile, "utf8"));
  scene.surfaces = placed;
  sceneFile = sceneFile.replace(/\.json$/, "-with-surfaces.json");
  fs.writeFileSync(sceneFile, JSON.stringify(scene));
  console.log(`rendered ${placed.length} SurfaceGuis in ${Date.now() - t2} ms`);
}
const sceneUrl = "/" + path.relative(repoRoot, sceneFile);
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
