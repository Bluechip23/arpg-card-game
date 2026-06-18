#!/bin/bash
# SessionStart hook: install Godot so scripts and scenes can be validated
# headlessly (imports, parse/compile checks, and the tests/ SceneTree scripts)
# during Claude Code on the web sessions.
#
# Runtime is ~1-2 min on a cold container while it downloads Godot (~70 MB);
# the container state is cached afterwards, so later sessions skip the download.
set -euo pipefail

# Only needed in remote (web) sessions — local machines bring their own Godot.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Keep this in step with project.godot's "config/features" engine version.
GODOT_VERSION="4.6-stable"
GODOT_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
INSTALL_DIR="$HOME/.local/share/godot"
BIN="$INSTALL_DIR/$GODOT_NAME"

if [ ! -x "$BIN" ]; then
  echo "[session-start] Installing Godot ${GODOT_VERSION}..."
  mkdir -p "$INSTALL_DIR"
  URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/${GODOT_NAME}.zip"
  curl -fsSL --retry 3 -o "$INSTALL_DIR/godot.zip" "$URL"
  unzip -o -q "$INSTALL_DIR/godot.zip" -d "$INSTALL_DIR"
  rm -f "$INSTALL_DIR/godot.zip"
  chmod +x "$BIN"
fi

# Expose a stable `godot` command and $GODOT_BIN for the rest of the session.
mkdir -p "$HOME/.local/bin"
ln -sf "$BIN" "$HOME/.local/bin/godot"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$HOME/.local/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
  echo "export GODOT_BIN=\"$BIN\"" >> "$CLAUDE_ENV_FILE"
fi

# Best-effort: a virtual display + software GL so scenes can be rendered to a PNG
# (e.g. tests/_capture_select.gd) and not just validated headlessly. This is
# optional — headless imports/tests work fine without it — so never fail here.
if ! command -v xvfb-run >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
  echo "[session-start] Installing virtual display + software GL (best effort)..."
  apt-get update -qq >/dev/null 2>&1 || true
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xvfb libgl1-mesa-dri libglx-mesa0 >/dev/null 2>&1 \
    || echo "[session-start] (rendering deps unavailable; headless validation still works)"
fi

# Pre-import resources so headless runs/tests are ready immediately.
"$BIN" --headless --import --path "$CLAUDE_PROJECT_DIR" >/dev/null 2>&1 || true

echo "[session-start] $("$BIN" --headless --version 2>/dev/null | tail -1) ready (godot on PATH)"
