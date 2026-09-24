// Camera setups for preview renders. Coordinates are Roblox studs
// (+X east, -Z north, Y up). "Player" views approximate the default
// third-person camera (about 12 studs behind, 4-6 above the head).
export const VIEW_SETS = {
  overview: [
    { name: "topdown", label: "TOP-DOWN (north up) — walking paths from spawn", ortho: 205, eye: [0, 500, 2], target: [0, 0, 2], paths: true },
    { name: "aerial-se", label: "AERIAL FROM SOUTH-EAST", eye: [230, 170, 250], target: [-10, 0, -10], fov: 50 },
    { name: "aerial-sw", label: "AERIAL FROM SOUTH-WEST", eye: [-240, 150, 230], target: [0, 0, -20], fov: 50 },
    { name: "spawn", label: "PLAYER VIEW AT SPAWN (facing north)", eye: [0, 9.5, 41], target: [0, 7, -40], fov: 70 },
    { name: "spawn-left", label: "PLAYER VIEW AT SPAWN (turned west)", eye: [10, 9.5, 30], target: [-80, 6, 10], fov: 70 },
    { name: "spawn-right", label: "PLAYER VIEW AT SPAWN (turned east)", eye: [-10, 9.5, 30], target: [80, 6, 0], fov: 70 },
    { name: "spawn-back", label: "PLAYER VIEW AT SPAWN (turned south)", eye: [0, 9.5, 14], target: [0, 6, 90], fov: 70 },
  ],
  detail: [
    { name: "ops-front", label: "OPERATIONS CENTER — APPROACH", eye: [0, 10, -34], target: [0, 12, -80], fov: 70 },
    { name: "ops-hall", label: "OPERATIONS CENTER — MATCHMAKING HALL", eye: [0, 11, -76], target: [0, 5, -104], fov: 72 },
    { name: "maproom", label: "MAP ROOM — INTERIOR", eye: [-100, 11, -78], target: [-100, 4, -112], fov: 72 },
    { name: "garage-front", label: "GARAGE — APPROACH", eye: [-50, 12, 10], target: [-100, 8, -2], fov: 70 },
    { name: "garage-hall", label: "GARAGE — DISPLAY HALL", eye: [-92, 13, 12], target: [-130, 3, -10], fov: 72 },
    { name: "hq-front", label: "COMMAND HQ — APPROACH", eye: [52, 10, -10], target: [100, 9, -20], fov: 70 },
    { name: "hq-office", label: "COMMAND HQ — COMMANDER'S OFFICE", eye: [94, 10, -18], target: [120, 4, -26], fov: 72 },
    { name: "leaderboards", label: "LEADERBOARDS — HALL OF COMMANDERS", eye: [110, 10, 50], target: [110, 7, 100], fov: 70 },
    { name: "events", label: "EVENT AREA — CURRENT OPERATION", eye: [-100, 11, 48], target: [-100, 6, 100], fov: 70 },
    { name: "missions", label: "MISSION BOARD", eye: [0, 8, 26], target: [0, 5, 44], fov: 70 },
    { name: "social", label: "SOCIAL AREA — CANTEEN COURTYARD", eye: [-6, 11, 64], target: [-6, 4, 120], fov: 72 },
    { name: "theater-map", label: "CENTRAL THEATRE MAP", eye: [0, 16, 18], target: [0, 1, -6], fov: 70 },
  ],
  closeup: [
    { name: "bikes", label: "BICYCLES AT THE CANTEEN", eye: [-26, 4, 103], target: [-17, 1.5, 109], fov: 60 },
    { name: "desk", label: "WATCH DESK", eye: [-4, 7, -118], target: [-4, 3.5, -124], fov: 60 },
  ],
  phase4: [
    { name: "courtyard", label: "CANTEEN COURTYARD — DETAILING", eye: [-6, 12, 72], target: [-6, 3, 100], fov: 72 },
    { name: "canteen", label: "CANTEEN — INTERIOR", eye: [-6, 8, 114], target: [-6, 3, 134], fov: 72 },
    { name: "parking", label: "STAFF PARKING", eye: [30, 14, 66], target: [55, 2, 100], fov: 70 },
    { name: "helipad", label: "HELIPAD", eye: [96, 14, 54], target: [118, 3, 29], fov: 70 },
    { name: "motorpool", label: "MOTOR POOL (VEHICLE SHED)", eye: [0, 11, -137], target: [-12, 4, -158], fov: 72 },
    { name: "gate", label: "MAIN GATE CHECKPOINT", eye: [168, 11, -38], target: [196, 3, -62], fov: 70 },
    { name: "ops-desks", label: "OPERATIONS CENTER — WATCH DESKS", eye: [0, 10, -104], target: [0, 5, -134], fov: 72 },
    { name: "briefing", label: "OPERATIONS CENTER — BRIEFING ROOM", eye: [37, 9, -108], target: [46, 4, -126], fov: 72 },
    { name: "signals", label: "OPERATIONS CENTER — SIGNALS ROOM", eye: [-37, 9, -76], target: [-46, 4, -100], fov: 72 },
    { name: "garage-workshop", label: "GARAGE — WORKSHOP SIDE", eye: [-92, 10, -30], target: [-112, 3, -42], fov: 72 },
    { name: "plaza-edge", label: "PARADE SQUARE — BENCHES AND LAMPS", eye: [-36, 8, -22], target: [-64, 2, -6], fov: 70 },
    { name: "street", label: "SOUTH ROAD — STREET LAMPS", eye: [96, 7, 58], target: [140, 6, 66], fov: 70 },
  ],
};
