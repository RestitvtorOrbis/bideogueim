#!/usr/bin/env sh
set -eu

version="$($GODOT_BIN --headless --version | tr -d '\r\n')"
case "$version" in
  "Godot Engine v4.7.1.stable."*) ;;
  *)
    echo "Expected Godot $GODOT_VERSION; got $version" >&2
    exit 2
    ;;
esac

exec "$GODOT_BIN" "$@"
