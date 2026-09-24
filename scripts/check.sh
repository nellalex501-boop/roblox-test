#!/usr/bin/env bash
# Static checks: Rojo build, Luau type-check (luau-lsp + Roblox definitions),
# StyLua formatting. Requires rojo, luau-lsp and stylua on PATH and
# ROBLOX_DEFS pointing at luau-lsp's globalTypes.d.luau
# (https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
echo "== rojo build"
rojo build default.project.json -o build/lobby.rbxl
rojo sourcemap default.project.json -o sourcemap.json
echo "== luau-lsp analyze"
luau-lsp analyze --platform roblox --sourcemap sourcemap.json \
  --definitions "@roblox=${ROBLOX_DEFS:?set ROBLOX_DEFS}" src
echo "== stylua --check"
stylua --check src tests
echo "OK"
