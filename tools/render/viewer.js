// Approximate preview renderer for the headless-built lobby.
// Reads the JSON exported by tests/lib/WorldChecks.export and draws every
// part with three.js. This is NOT Roblox rendering: materials are flat
// colours with roughness, lighting is a single sun + sky. It exists to check
// layout, massing, silhouettes, colours and sign readability from a
// container where Roblox Studio cannot run.
import * as THREE from "three";
import { mergeGeometries } from "three/addons/utils/BufferGeometryUtils.js";

const params = new URLSearchParams(location.search);
const width = Number(params.get("w") || 1600);
const height = Number(params.get("h") || 900);

const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(1);
renderer.setSize(width, height);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
renderer.outputColorSpace = THREE.SRGBColorSpace;
document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
const skyColor = new THREE.Color(0xb7c0c4);
scene.background = skyColor;
scene.fog = new THREE.Fog(0xb5bcbc, 260, 950);

const hemi = new THREE.HemisphereLight(0xdfe6ea, 0x5a6040, 0.95);
scene.add(hemi);
const sun = new THREE.DirectionalLight(0xfff1dc, 2.1);
sun.position.set(-160, 220, 170);
sun.target.position.set(0, 0, 0);
sun.castShadow = true;
sun.shadow.mapSize.set(4096, 4096);
const sc = sun.shadow.camera;
sc.left = -320; sc.right = 320; sc.top = 320; sc.bottom = -320; sc.near = 10; sc.far = 900;
sun.shadow.bias = -0.0004;
sun.shadow.normalBias = 0.6;
scene.add(sun);
scene.add(sun.target);

const perspective = new THREE.PerspectiveCamera(70, width / height, 0.5, 3000);
let camera = perspective;

const MATERIALS = {
  SmoothPlastic: { roughness: 0.62, metalness: 0.0 },
  Plastic: { roughness: 0.66, metalness: 0.0 },
  Concrete: { roughness: 0.95, metalness: 0.0 },
  Pavement: { roughness: 0.95, metalness: 0.0 },
  Asphalt: { roughness: 0.98, metalness: 0.0 },
  Brick: { roughness: 0.92, metalness: 0.0 },
  Cobblestone: { roughness: 0.95, metalness: 0.0 },
  Slate: { roughness: 0.85, metalness: 0.0 },
  Granite: { roughness: 0.8, metalness: 0.0 },
  Marble: { roughness: 0.5, metalness: 0.0 },
  Grass: { roughness: 1.0, metalness: 0.0 },
  LeafyGrass: { roughness: 1.0, metalness: 0.0 },
  Ground: { roughness: 1.0, metalness: 0.0 },
  Mud: { roughness: 1.0, metalness: 0.0 },
  Sand: { roughness: 1.0, metalness: 0.0 },
  Snow: { roughness: 0.9, metalness: 0.0 },
  Ice: { roughness: 0.2, metalness: 0.0 },
  Wood: { roughness: 0.85, metalness: 0.0 },
  WoodPlanks: { roughness: 0.85, metalness: 0.0 },
  Fabric: { roughness: 1.0, metalness: 0.0 },
  Metal: { roughness: 0.45, metalness: 0.55 },
  CorrodedMetal: { roughness: 0.8, metalness: 0.35 },
  DiamondPlate: { roughness: 0.5, metalness: 0.55 },
  Foil: { roughness: 0.3, metalness: 0.7 },
  Glass: { roughness: 0.12, metalness: 0.2 },
  Rubber: { roughness: 0.95, metalness: 0.0 },
};

function wedgeGeometry(sx, sy, sz) {
  const x = sx / 2, y = sy / 2, z = sz / 2;
  // Roblox wedge: bottom + back (+Z) faces full, slope down toward -Z.
  const A = [-x, -y, -z], B = [x, -y, -z], C = [x, -y, z], D = [-x, -y, z];
  const E = [-x, y, z], F = [x, y, z];
  const tris = [
    [A, C, B], [A, D, C],          // bottom
    [D, F, C], [D, E, F],          // back (+Z)
    [A, B, F], [A, F, E],          // slope
    [A, E, D],                      // left side (-X)
    [B, C, F],                      // right side (+X)
  ];
  const pos = [];
  for (const t of tris) for (const v of t) pos.push(...v);
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  g.computeVertexNormals();
  return g;
}

function partGeometry(p) {
  const [sx, sy, sz] = p.z;
  let g;
  if (p.s === "Wedge" || p.s === "CornerWedge") {
    g = wedgeGeometry(sx, sy, sz);
  } else if (p.s === "Cylinder") {
    const r = Math.min(sy, sz) / 2;
    g = new THREE.CylinderGeometry(r, r, sx, Math.max(10, Math.min(28, Math.round(r * 6))));
    g.rotateZ(-Math.PI / 2);
  } else if (p.s === "Ball") {
    const r = Math.min(sx, sy, sz) / 2;
    g = new THREE.SphereGeometry(r, 24, 16);
  } else {
    g = new THREE.BoxGeometry(sx, sy, sz);
  }
  g = g.index ? g.toNonIndexed() : g;
  const c = p.c;
  const m = new THREE.Matrix4().set(
    c[3], c[4], c[5], c[0],
    c[6], c[7], c[8], c[1],
    c[9], c[10], c[11], c[2],
    0, 0, 0, 1,
  );
  g.applyMatrix4(m);
  const color = new THREE.Color().setRGB(p.k[0] / 255, p.k[1] / 255, p.k[2] / 255, THREE.SRGBColorSpace);
  const count = g.attributes.position.count;
  const colors = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    colors[i * 3] = color.r; colors[i * 3 + 1] = color.g; colors[i * 3 + 2] = color.b;
  }
  g.setAttribute("color", new THREE.BufferAttribute(colors, 3));
  for (const key of Object.keys(g.attributes)) {
    if (key !== "position" && key !== "normal" && key !== "color") g.deleteAttribute(key);
  }
  return g;
}

const root = new THREE.Group();
scene.add(root);
const overlay = new THREE.Group();
scene.add(overlay);
window.__stats = {};

async function loadScene(url) {
  const data = await (await fetch(url)).json();
  const buckets = new Map();
  let count = 0;
  for (const p of data.parts) {
    const neon = p.m === "Neon";
    const transparent = p.t > 0.05;
    const key = neon ? "Neon" : (transparent ? `T:${p.m}:${p.t.toFixed(2)}` : p.m);
    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(partGeometry(p));
    count++;
  }
  for (const [key, geos] of buckets) {
    const merged = mergeGeometries(geos, false);
    let material;
    if (key === "Neon") {
      material = new THREE.MeshBasicMaterial({ vertexColors: true });
      material.color.setScalar(1.6);
    } else if (key.startsWith("T:")) {
      const [, mat, t] = key.split(":");
      const props = MATERIALS[mat] || MATERIALS.SmoothPlastic;
      material = new THREE.MeshStandardMaterial({ vertexColors: true, ...props, transparent: true, opacity: 1 - Number(t), depthWrite: false });
    } else {
      const props = MATERIALS[key] || MATERIALS.SmoothPlastic;
      material = new THREE.MeshStandardMaterial({ vertexColors: true, ...props });
    }
    const mesh = new THREE.Mesh(merged, material);
    mesh.castShadow = !key.startsWith("T:");
    mesh.receiveShadow = true;
    root.add(mesh);
  }
  window.__stats.parts = count;
  window.__stats.buckets = buckets.size;

  // Surface GUI textures rendered by the GUI pass.
  if (data.surfaces) {
    const loader = new THREE.TextureLoader();
    const jobs = data.surfaces.map((s) => new Promise((resolve) => {
      loader.load(s.image, (tex) => {
        tex.colorSpace = THREE.SRGBColorSpace;
        tex.anisotropy = 8;
        const mat = new THREE.MeshStandardMaterial({ map: tex, roughness: 0.8, transparent: true, emissive: new THREE.Color(0xffffff), emissiveMap: tex, emissiveIntensity: s.glow ?? 0.25 });
        const plane = new THREE.Mesh(new THREE.PlaneGeometry(s.w, s.h), mat);
        const c = s.c;
        const m = new THREE.Matrix4().set(c[3], c[4], c[5], c[0], c[6], c[7], c[8], c[1], c[9], c[10], c[11], c[2], 0, 0, 0, 1);
        plane.applyMatrix4(m);
        plane.receiveShadow = true;
        root.add(plane);
        resolve();
      }, undefined, () => resolve());
    }));
    await Promise.all(jobs);
    window.__stats.surfaces = data.surfaces.length;
  }

  if (data.extra && data.extra.paths) {
    const palette = [0xe0a84a, 0x7fb3d5, 0xc8553d, 0x9ccc65, 0xf2e394, 0xba68c8, 0x4db6ac, 0xff8a65];
    data.extra.paths.forEach((path, i) => {
      const pts = path.points.map(([x, z]) => new THREE.Vector3(x, 1.2, z));
      const geo = new THREE.BufferGeometry().setFromPoints(pts);
      const line = new THREE.Line(geo, new THREE.LineBasicMaterial({ color: palette[i % palette.length], linewidth: 3, depthTest: false }));
      line.renderOrder = 10;
      overlay.add(line);
    });
    overlay.visible = false;
  }
  addFigures(data.extra && data.extra.figures);
  return count;
}

// Simple 5.3-stud tall stand-ins for players, for scale.
function addFigures(list) {
  if (!list) return;
  const body = new THREE.MeshStandardMaterial({ color: 0x6d7f96, roughness: 0.7 });
  const skin = new THREE.MeshStandardMaterial({ color: 0xd8b28a, roughness: 0.7 });
  const legs = new THREE.MeshStandardMaterial({ color: 0x3b4252, roughness: 0.8 });
  for (const f of list) {
    const g = new THREE.Group();
    const torso = new THREE.Mesh(new THREE.BoxGeometry(2, 2, 1), body); torso.position.y = 3.0;
    const head = new THREE.Mesh(new THREE.BoxGeometry(1.2, 1.2, 1.2), skin); head.position.y = 4.6;
    const leg1 = new THREE.Mesh(new THREE.BoxGeometry(0.9, 2, 1), legs); leg1.position.set(-0.5, 1, 0);
    const leg2 = new THREE.Mesh(new THREE.BoxGeometry(0.9, 2, 1), legs); leg2.position.set(0.5, 1, 0);
    const arm1 = new THREE.Mesh(new THREE.BoxGeometry(0.8, 2, 0.8), body); arm1.position.set(-1.45, 3, 0);
    const arm2 = new THREE.Mesh(new THREE.BoxGeometry(0.8, 2, 0.8), body); arm2.position.set(1.45, 3, 0);
    for (const m of [torso, head, leg1, leg2, arm1, arm2]) { m.castShadow = true; g.add(m); }
    g.position.set(f[0], f[1], f[2]);
    g.rotation.y = f[3] || 0;
    scene.add(g);
  }
}

function setView(view) {
  const label = document.getElementById("label");
  label.textContent = view.label || "";
  label.style.display = view.label ? "block" : "none";
  overlay.visible = !!view.paths;
  if (view.ortho) {
    const s = view.ortho;
    const aspect = width / height;
    camera = new THREE.OrthographicCamera(-s * aspect, s * aspect, s, -s, 1, 3000);
    camera.position.set(...view.eye);
    camera.up.set(0, 0, -1);
    camera.lookAt(new THREE.Vector3(...view.target));
    scene.fog.near = 5000; scene.fog.far = 6000;
  } else {
    camera = perspective;
    camera.up.set(0, 1, 0);
    camera.fov = view.fov || 70;
    camera.updateProjectionMatrix();
    camera.position.set(...view.eye);
    camera.lookAt(new THREE.Vector3(...view.target));
    scene.fog.near = view.fogNear || 260; scene.fog.far = view.fogFar || 950;
  }
  renderer.render(scene, camera);
  return true;
}

window.loadScene = loadScene;
window.setView = setView;
window.__ready = true;
