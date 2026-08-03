#!/usr/bin/env sh
set -eu

version="$($GODOT_BIN --headless --version | tr -d '\r\n')"
case "$version" in
  "4.7.1.stable."*) ;;
  "Godot Engine v4.7.1.stable."*) ;;
  *)
    echo "Expected Godot $GODOT_VERSION; got $version" >&2
    exit 2
    ;;
esac

if [ -f /workspace/project.godot ]; then
  "$GODOT_BIN" --headless --path /workspace --editor --import --quit
fi

exec "$GODOT_BIN" "$@"
